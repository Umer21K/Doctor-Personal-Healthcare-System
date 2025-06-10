
import os
import argparse
import multiprocessing
from pathlib import Path
import subprocess

import torch
import pandas as pd
from datasets import Dataset
from unsloth import FastLanguageModel, to_sharegpt, standardize_sharegpt, apply_chat_template
from transformers import (
    TrainingArguments,
    DataCollatorForSeq2Seq,
    EarlyStoppingCallback,
)
from trl import SFTTrainer
from transformers.trainer_callback import TrainerCallback
from transformers.trainer_utils import PREFIX_CHECKPOINT_DIR
from huggingface_hub import snapshot_download


def parse_args():
    parser = argparse.ArgumentParser(description="Fine-tune LLM for lab-test recommendation")
    parser.add_argument("--data", type=Path, default=Path("unified_training_table.csv"),
                        help="Path to training CSV")
    parser.add_argument("--model_name", type=str, default="deepseek-ai/deepseek-llm-7b-base")
    parser.add_argument("--output_dir", type=Path, default=Path("medical_finetuned"))
    parser.add_argument("--max_steps", type=int, default=1000)
    parser.add_argument("--batch_size", type=int, default=8)
    parser.add_argument("--accum_steps", type=int, default=4)
    parser.add_argument("--lr", type=float, default=2e-4)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--offline", action="store_true",
                        help="Load model from local cache without downloading")
    return parser.parse_args()


def load_medical_data(csv_path: Path) -> Dataset:
    df = pd.read_csv(csv_path)
    df.dropna(subset=["LAB_REQUESTS", "PRESENTING_COMPLAIN"], inplace=True)

    def format_inst(row):
        return (
            f"Patient Info:\n"
            f"- Sex: {row['MR_SEX']}; Age: {row['AGE_AT_VISIT']}\n"
            f"- Complaint: {row['PRESENTING_COMPLAIN']}\n"
            f"- Vitals: BP {row['BP_SYSTOLIC']}/{row['BP_DIASTOLIC']} mmHg, Temp {row['TEMP']}°C\n"
            f"- Diagnosis: {row.get('DIAGNOSIS') or row.get('FINAL_DIAGNOSIS')}"
        )

    records = []
    for _, row in df.iterrows():
        records.append({"instruction": format_inst(row), "input": "", "output": row["LAB_REQUESTS"]})
    return Dataset.from_pandas(pd.DataFrame(records))


class SavePeftModelCallback(TrainerCallback):
    """Callback to save only PEFT adapters during training checkpoints"""

    def on_save(self, args, state, control, **kwargs):
        ckpt = os.path.join(args.output_dir, f"{PREFIX_CHECKPOINT_DIR}-{state.global_step}")
        os.makedirs(ckpt, exist_ok=True)
        model = kwargs.get("model")
        if model:
            model.save_pretrained(ckpt)
        return control


def main():
    args = parse_args()
    torch.manual_seed(args.seed)

    os.environ["TOKENIZERS_PARALLELISM"] = "false"
    torch.backends.cudnn.benchmark = True
    torch.backends.cuda.matmul.allow_tf32 = True
    torch.backends.cudnn.allow_tf32 = True

    assert torch.cuda.is_available(), "CUDA is required for GPU training"
    cpu_workers = max(1, multiprocessing.cpu_count() - 2)
    print(f"Using {cpu_workers} data loader workers.")


    raw_ds = load_medical_data(args.data)
    ds = to_sharegpt(raw_ds, merged_prompt="{instruction}\n\nContext:\n{input}", output_column_name="output")
    ds = standardize_sharegpt(ds)
    chat_template = "You are a clinical support system.\nPatient Case:\n{INPUT}\nRecommended Tests:\n{OUTPUT}"

    name = args.model_name
    try:
        print("Loading model from local cache...")
        model, tokenizer = FastLanguageModel.from_pretrained(
            model_name=name, max_seq_length=2048, load_in_4bit=True,
            device_map="auto", local_files_only=True
        )
    except OSError:
        print("Cache miss—downloading via snapshot_download...")
        path = snapshot_download(repo_id=name)
        print(f"Downloaded to {path}, now loading...")
        model, tokenizer = FastLanguageModel.from_pretrained(
            model_name=path, max_seq_length=2048, load_in_4bit=True,
            device_map="auto", local_files_only=True
        )
]
    if hasattr(tokenizer, "unsloth_push_to_hub"):
        delattr(tokenizer, "unsloth_push_to_hub")

    model = FastLanguageModel.get_peft_model(
        model, r=8, target_modules=["q_proj", "k_proj", "v_proj", "o_proj"],
        lora_alpha=32, lora_dropout=0.1, bias="none",
        use_gradient_checkpointing="unsloth", random_state=args.seed
    )
    model.gradient_checkpointing_enable()

    ds = apply_chat_template(ds, tokenizer, chat_template)
    ds = ds.map(
        lambda b: tokenizer(b['text'], truncation=True, padding='max_length', max_length=1024),
        batched=True, num_proc=min(1, cpu_workers), remove_columns=ds.column_names  # reduced to 1 for Windows stability
    )
    collator = DataCollatorForSeq2Seq(tokenizer, pad_to_multiple_of=8)

    fp16 = torch.cuda.is_available() and not torch.cuda.is_bf16_supported()
    bf16 = torch.cuda.is_bf16_supported()
    training_args = TrainingArguments(
        output_dir=str(args.output_dir),
        max_steps=args.max_steps,
        per_device_train_batch_size=args.batch_size,
        gradient_accumulation_steps=args.accum_steps,
        learning_rate=args.lr,
        fp16=fp16,
        bf16=bf16,
        weight_decay=0.01,
        eval_strategy="steps",
        eval_steps=200,
        load_best_model_at_end=True,
        metric_for_best_model="eval_loss",
        greater_is_better=False,
        lr_scheduler_type="cosine",
        logging_steps=50,
        save_steps=200,
        save_total_limit=3,
        dataloader_num_workers=0,  
        gradient_checkpointing=True,
        seed=args.seed,
    )

    callbacks = [EarlyStoppingCallback(early_stopping_patience=3), SavePeftModelCallback()]
    trainer = SFTTrainer(
        model=model, tokenizer=tokenizer, args=training_args,
        train_dataset=ds,
        eval_dataset=ds.select(range(min(500, len(ds)))),
        data_collator=collator,
        packing=False,  
    )
    trainer.train()

    model.save_pretrained(args.output_dir)
    tokenizer.save_pretrained(args.output_dir)
]
    mf = args.output_dir / "Modelfile"
    mf.write_text(f"""FROM {args.output_dir}
SYSTEM You are a medical expert specializing in lab-test recommendations.
PARAMETER temperature 0.3
PARAMETER num_ctx 2048
""")
    subprocess.run(["ollama", "create", "deepseek-med", "-f", str(mf)], check=True)
    print("Done: adapters saved & Ollama model created.")


if __name__ == '__main__':

    multiprocessing.set_start_method("spawn", force=True)
    multiprocessing.freeze_support()
    main()
