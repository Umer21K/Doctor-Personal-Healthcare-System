import os
import json
import numpy as np
from flask import Response
import re
import asyncio
import traceback
from datetime import datetime as _dt
from flask import Flask, request, jsonify, render_template
from dotenv import load_dotenv
import pandas as pd

# Azure imports
from azure.cosmos.aio import CosmosClient
from azure.cosmos import exceptions
from azure.identity import ClientSecretCredential
from azure.keyvault.secrets import SecretClient

# LangChain imports
from langchain_core.prompts import (
    SystemMessagePromptTemplate,
    HumanMessagePromptTemplate,
    ChatPromptTemplate
)
from langchain_ollama import OllamaLLM

load_dotenv()

# Azure Key Vault credentials
client_id     = os.environ['AZURE_CLIENT_ID']
tenant_id     = os.environ['AZURE_TENANT_ID']
client_secret = os.environ['AZURE_CLIENT_SECRETS']
vault_url     = os.environ['AZURE_VAULT_URL']

# Secret names
secret_name1 = "Cosmo-db-URL"
secret_name2 = "Cosmo-db-key"

credentials = ClientSecretCredential(
    client_id=client_id,
    client_secret=client_secret,
    tenant_id=tenant_id,
)
secret_client = SecretClient(vault_url=vault_url, credential=credentials)
secret1 = secret_client.get_secret(secret_name1)
secret2 = secret_client.get_secret(secret_name2)
URL = secret1.value
KEY = secret2.value
DATABASE_NAME     = 'User_Info_db'
CONTAINER_NAME    = 'User_Info'
PARTITION_KEY_PATH = '/id'

app = Flask(__name__)

def parse_visit_date(date_str: str) -> _dt.date:
    for fmt in ("%m/%d/%Y", "%#m/%#d/%Y", "%m/%d/%y", "%#m/%#d/%y"):
        try:
            return _dt.strptime(date_str, fmt).date()
        except ValueError:
            continue
    raise ValueError(f"Invalid date format: {date_str}")

def parse_date_only(date_str, fmt="%m/%d/%Y"):
    try:
        return pd.to_datetime(date_str, format=fmt).date()
    except Exception:
        return None

def clean_df(df):
    df.columns = df.columns.str.strip()
    for col in df.select_dtypes(include=['object']).columns:
        df[col] = df[col].str.strip()
    return df

# — Cosmos async helpers (unchanged) —
async def add_user_async(name: str, password: str, email: str, role: str, department: str):
    try:
        async with CosmosClient(URL, credential=KEY) as client:
            db = client.get_database_client(DATABASE_NAME)
            container = db.get_container_client(CONTAINER_NAME)

            # Compute new numeric ID
            query = "SELECT c.id FROM c"
            items = container.query_items(query=query, partition_key=None)
            max_id = 0
            async for item in items:
                id_str = item.get('id')
                if id_str and id_str.isdigit():
                    max_id = max(max_id, int(id_str))
            new_id = max_id + 1

            user_doc = {
                'id': str(new_id),
                'name': name,
                'password': password,
                'email': email,
                'role': role,
                'department': department
            }
            await container.upsert_item(user_doc)

            return {
                "status": "success",
                "user_id": new_id,
                "username": name,
                "role": role,
                "department": department
            }
    except exceptions.CosmosHttpResponseError as e:
        return {"status": "error", "message": str(e)}

async def validate_user_async(password: str, email: str):
    try:
        async with CosmosClient(URL, credential=KEY) as client:
            db = client.get_database_client(DATABASE_NAME)
            container = db.get_container_client(CONTAINER_NAME)

            query = "SELECT * FROM c WHERE c.password = @pwd AND c.email = @mail"
            parameters = [
                {"name": "@pwd", "value": password},
                {"name": "@mail", "value": email}
            ]
            items = container.query_items(query=query, parameters=parameters, partition_key=None)
            async for item in items:
                return {
                    'userid':     item['id'],
                    'username':   item['name'],
                    'password':   item['password'],
                    'email':      item['email'],
                    'role':       item.get('role', 'user'),
                    'department': item.get('department', 'Unknown')
                }
            return None
    except exceptions.CosmosHttpResponseError as e:
        return {"status": "error", "message": str(e)}

async def delete_user_async(user_id: str):
    try:
        async with CosmosClient(URL, credential=KEY) as client:
            db = client.get_database_client(DATABASE_NAME)
            container = db.get_container_client(CONTAINER_NAME)

            await container.delete_item(item=user_id, partition_key=user_id)
            return {"status": "success", "deleted_user_id": user_id}
    except exceptions.CosmosHttpResponseError as e:
        if hasattr(e, 'status_code') and e.status_code == 404:
            return {"status": "failure", "message": f"User with id {user_id} not found."}
        return {"status": "error", "message": str(e)}


# — CSV-based retrieval —
def get_registration_records(mr_code):
    df = pd.read_csv('mr_registiration.csv', dtype={'MR_CODE': str})
    df = clean_df(df)
    df = df.replace({np.nan: None})

    # 4) Filter
    filtered = df[(df['MR_CODE'] == mr_code)]

    return filtered.to_dict(orient='records')

def get_presenting_complain_records(mr_code, mr_visit_date):
    df = pd.read_csv('presinting_complain.csv', dtype={'MR_CODE': str, 'MR_VISIT_DATE': str})
    df = clean_df(df)

    # Parse visit-date into a date object
    df['VISIT_DATE_ONLY'] = (
        pd.to_datetime(
            df['MR_VISIT_DATE'].str.split().str[0],
            format='%m/%d/%Y',
            errors='coerce'
        )
        .dt.date
    )


    # Normalize input date
    mr_visit_date_obj = parse_date_only(mr_visit_date)
    if mr_visit_date_obj is None:
        return []

    df = df.replace({np.nan: None})

    filtered = df[
        (df['MR_CODE'] == mr_code) &
        (df['VISIT_DATE_ONLY'] == mr_visit_date_obj)
        ]
    return filtered.to_dict(orient='records')

def get_vitals_records(mr_code, mr_visit_date):
    df = pd.read_csv(
        'vitals.csv',
        dtype={'MR_CODE': str, 'MR_VISITDATE': str}
    )
    df = clean_df(df)

    df['VISIT_DATE_ONLY'] = (
        pd.to_datetime(
            df['MR_VISITDATE'].str.split().str[0],
            format='%m/%d/%Y',
            errors='coerce'
        )
        .dt.date
    )
    mr_visit_date_obj = parse_date_only(mr_visit_date)

    if mr_visit_date_obj is None:
        return []

    df = df.replace({np.nan: None})


    filtered = df[
        (df['MR_CODE'] == mr_code) &
        (df['VISIT_DATE_ONLY'] == mr_visit_date_obj)
        ]
    print(filtered)
    return filtered.to_dict(orient='records')

def get_diagnoses_records(mr_code, mr_visit_date):
    df = pd.read_csv(
        'Diagnosis.csv',
        dtype={'MR_CODE': str, 'MR_VISIT_DATE': str}
    )
    df = clean_df(df)

    df['VISIT_DATE_ONLY'] = (
        pd.to_datetime(
            df['MR_VISIT_DATE'].str.split().str[0],
            format='%m/%d/%Y',
            errors='coerce'
        )
        .dt.date
    )

    mr_visit_date_obj = parse_date_only(mr_visit_date)

    if mr_visit_date_obj is None:
        return []

    df = df.replace({np.nan: None})



    filtered = df[
        (df['MR_CODE'] == mr_code) &
        (df['VISIT_DATE_ONLY'] == mr_visit_date_obj)
        ]
    return filtered.to_dict(orient='records')

def get_lab_request_records(mr_code, mr_visit_date):
    df = pd.read_csv('lab_request.csv', dtype={'MR_CODE': str, 'MR_VISIT_DATE': str})

    df = clean_df(df)

    df['VISIT_DATE_ONLY'] = (
        pd.to_datetime(
            df['MR_VISIT_DATE'].str.split().str[0],
            format='%m/%d/%Y',
            errors='coerce'
        )
        .dt.date
    )

    mr_visit_date_obj = parse_date_only(mr_visit_date)

    if mr_visit_date_obj is None:
        return []

    df = df.replace({np.nan: None})

    filtered = df[(df['MR_CODE'] == mr_code) & (df['VISIT_DATE_ONLY'] == mr_visit_date_obj)]
    return filtered.to_dict(orient='records')

def get_lab_result_records(mr_code, mr_visit_date):
    # Get request numbers
    lr_df = pd.read_csv(
        'lab_request.csv',
        dtype={'MR_CODE': str, 'MR_VISIT_DATE': str, 'LRS_NO': str}
    )
    # strip whitespace
    lr_df['MR_CODE'] = lr_df['MR_CODE'].str.strip()
    lr_df['MR_VISIT_DATE'] = lr_df['MR_VISIT_DATE'].str.strip()
    lr_df['LRS_NO'] = lr_df['LRS_NO'].str.strip()
    # extract & parse date-only
    lr_df['VISIT_DATE_ONLY'] = pd.to_datetime(
        lr_df['MR_VISIT_DATE'].str.split().str[0],
        format='%m/%d/%Y',
        errors='coerce'
    ).dt.date

    # normalize inputs
    mr_code_str = str(mr_code).strip()
    mr_visit_date_obj = parse_date_only(mr_visit_date)

    # filter lab_request on code + date
    matching_lrs = lr_df.loc[
        (lr_df['MR_CODE'] == mr_code_str) &
        (lr_df['VISIT_DATE_ONLY'] == mr_visit_date_obj),
        'LRS_NO'
    ]

    if matching_lrs.empty:
        print(f"No lab request found, cannot retrieve lab results for "
              f"MR_CODE={mr_code_str}, MR_VISIT_DATE={mr_visit_date_obj}.")
        return

    # 2) Read & clean lab_result.csv
    df = pd.read_csv(
        'lab_result.csv',
        dtype={'LRS_NO': str, 'INSERT_DT': str}
    )
    df = clean_df(df)
    df['LRS_NO'] = df['LRS_NO'].str.strip()
    df['INSERT_DT'] = df['INSERT_DT'].str.strip()
    # extract & parse date-only
    df['INSERT_DATE_ONLY'] = pd.to_datetime(
        df['INSERT_DT'].str.split().str[0],
        format='%m/%d/%Y',
        errors='coerce'
    ).dt.date

    mr_visit_date_obj = parse_date_only(mr_visit_date)

    if mr_visit_date_obj is None:
        return []

    df = df.replace({np.nan: None})

    # filter for both LRS_NO match and same insert date
    filtered = df.loc[
        df['LRS_NO'].isin(matching_lrs) &
        (df['INSERT_DATE_ONLY'] == mr_visit_date_obj)
        ]
    return filtered.to_dict(orient='records')

def get_medication_records(mr_code):
    df = pd.read_csv(
        'medication.csv',
        dtype={'MR_CODE': str}
    )
    df = clean_df(df)


    df = df.replace({np.nan: None})


    # 5) Filter on MR_CODE + date-only
    filtered = df[
        (df['MR_CODE'] == mr_code)
        ]
    return filtered.to_dict(orient='records')



# — Department guidance —
def get_dept_text(department: str) -> str:
    dept = department
    if dept == '19 A':
        dept_text = 'You work in 19A Department , so the most likely Diagnosis should be among these : ACHALESIA CARDIA, ACUTE APPENDICITIS, ADHESIVE OBSTRUCTION, ARM WITH RVF, INGUINAL HERNIA, TEV, UNDESCENDED TESTES, BAND OBSTRUCTION, BILIARY ATRESIA, CHOLEDOCHAL CYST, CHOLELITHIASIS, CONCEALED PENIS, CYSTIC HYGROMA, DUODENAL PERFORATION, ENTERIC PERFORATION, ESOPHAGEAL ATRESIA, ESOPHAGEAL STRICTURE, TRAUMA, FOREIGN BODY ASPIRATION, HEMANGIOMA, HX DISEASE, HYPOSPADIAS, IMPACTED URETHRAL STONE, INFECTED WOUND, INTESTINAL OBSTRUCTION ADHESIONS, INTUSSUSCEPTION, TORTICOLIS, VUJO, MESENTERIC CYST, MEATAL STENOSIS, ABSCESS, OVARIAN CYST, PNEUNONIA, PRIMARY PERITONITIS, PUJO, RECTAL POLYP, EPIDIDYMO-ORCHITIS, STOMA CLOSURE, SUB ACUTE INTESTINAL OBSTRUCTION, THYROGLOSSAL CYST, UG SINUS, VAGINAL ATRESIA, VESICAL CALCULI .'
        return dept_text
    elif dept == 'SICU':
        dept_text = 'You work in the Surgical ICU'
        return dept_text
    elif dept == '19 B':
         dept_text = 'You work in ward 19 B, so the most likely Diagnosis should be among these : ACUTE EXACERBATION OF ASTHMA, INFANTILE HYPERTROPHIC PYLORIC STENOSIS, ARM, Cyst, UNKNOWN POISONING/DRUG OVER DOSE, ILEAL ARESIA, HYDROCEPHSLUS, RTA, THALESEMIA, Hirchsprung Disease, Foreign Body Aspiration, Stomal Diarrhea, Right Testicular Mass, BLEEDING DISORDER, ALL, HEPATITIS, Dog Bite, Omphalitis, Malrotation, Rectal Polyp, Ovarian Mass, Tongue Tie, SEPTIC SHOCK, VENTRICULITIS, UTI, Posterior Urethral Value, Worm Infestation, Midgut Volvolus, PREES SYNDROME, Congenital Diaphragmatic Hernia, Circumcision then Developed Phimosis, Post Appendiceal Pain + Menstraul Pain, Esophageal Stricture, Cystic Hygroma, Torsion of Appendicular Testis + Epididymorchitis, INTESTINAL OBSTRUCTION , Didelphys + Vagineal Septum + Obstructive Uropathy, Tracheal Stenosis, Mesenteric Adenitis, Functional Constipation + Fecal Loading 2` to Constipation, Left Gluteal Discharging Sinus, Post Circumcision Meatoplasty, Non Obstructing Pelvi-Ureteric Junction Calculus + Mild Hydroureter, Left Posterior Thigh Cellulitis, K/C Cloacal Malformation With Ambigous Genitalia, Left Sided Perianal Swelling, Lymphoproliferative Disease, Occipital Complex Mass, Cervical Lymphadenopathy, UG Sinus + Left Solitary Kidney, Wound Infection, Colonic Atresia, Pyogenic Granuloma on Left Side of Scalp'
         return dept_text
    elif dept == 'ITU':
        dept_text = 'You work in the ITU Department, so the most likely Diagnosis should be among these : Left CDH, Cloacal Malformation, Meconium ileus, INTRAVENTICULAR HEMMORHAGE/MENINGITIS, Right Irreducible Inguinal Hernia, IRON DECIFIENCY ANEMIA, Suspected Hirchsprung Disease, Right Undescended Testis, INFENTILE LEUKEMIA, Omphalocele Minor With POMD, FOCAL FATTY INFILTRATION IN LIVER, Proximal Small Bowel Atresia with Rectal Atresia'
        return dept_text
    elif dept == 'BURN':
        dept_text = 'You work in the Burn Unit'
        return dept_text
    elif dept == 'MEDICAL UNIT I':
        dept_text = 'You’re on Medical Unit I, so the most likely Diagnosis should be among these : ACUTE GASTORENTERITIS, MEASLES e PNEUMONIA/ENCEPHALITIS, ENTERIC FEVER/TYPHOID, URINARY TRACT INFECTION, METABOLIC FITS/SEIZURE DISORDER?, AKI e ACUTE GASTROENTERITIS, DOWN SYNDROME/BRONCHOPNEUMONIA?, TERATOMA, BRONCHIOLITIS, PNEUMONIA e SEPSIS, ALL e CHICKEN POX, ACUTE LEUKEMIA(JML), LT SIDED PLEURAL EFFUSION, ACUTE LIVER FAILURE, EMPYSEMA THORACIC, BRONCHOPNEUMONIA, ACUTE FEBRILE ILLUS, K/C OF THALASSEMIA, MENINGOENCEPHALITIS, NEONATAL CHOLESTASIS SEC TO, MENINGITIS/ENCEPHALITIS, LYMPHOMA, AML, K/C THALASSEMIA MAJOR e BRONCHOPNEUMONIA, FEBRILE FITS, ANEMIA SEC TO??, LT HIP SEPTIC ARTHRITIS, OSTEOPETROSIS, GANGLIONEUROMA?, NEONATAL CHOLESTASIS SEC TO, CP CHILD e ASPIRATION PNEUMONIA, VIRAL ENCEPHALIYS, ABDOMINAL TB, CEREBRAL PALSY/PNEUMONIA?, AUTOIMMUNE HEMOLYTIC ANEMIA, LOBAR PNEUMONIA, ANEMIC FAILURE, GLANZMAN THROMBASTHENIA, METABOLIC FITS/MENINGITIS?, GBS, ACUTE VIRAL HEPATITIS, PANCYTOPENIA SEC TO BRONCHOPNEUMONIA, B/L PNEUMOTHORAX SEC TO TB, BILLIARY ATRESIA/FACTOR X DEFICIENCY?, SNAKE POISONING, PCM+ACUTE VIRAL HEPATITES, APLASTIC ANEMIA?/PANCYTOPENIA SEC TO?, SEPTIC SHOCK?/3RD DEGREE BURN?, LYMPHOPROLIFERATIVE DISORDER?/APLASTIC ANEMIA, CYSTIC FIBROSIS, CHD e COMPLICATION/BRAIN ABSCESS, BRAIN ABCESS, SSPE e ASPIRATION PNEUMONIA, SEPTIC ARTHRITIS/OLIGOARTICULAR (JIA), CP e PNEUMONIA, BLEEDING DISORDER SEC TO PLATELET FUNCTION DISORDER, BLEACH INGESTION TOXIC EFFECTS OF ALKALI, PETROLEUM INGESTION POISONING, CHOLERA, ALL/MUMPS, REACTIVE AIRWAY DISEASE, POST BURNS COMPLICATION/ANEMIC FAILURE?, SEPSIS e SEPTIC SHOCK, POST MEASLES e PNEUMONIA, POST MENINGITIS SEQUALE, ACUTE KIDNEY INJURY, PULMONARY TB, PYOGENIC MENINGITS, CHD e MYOCARDITIS, ROAD TRAFFIC ACCIDENT, RICKETS/DELAYED MILESTONES, RT SIDED EMPYEMA, BULBAR PALSY SEC TO HSV ENCEPHALITIS, RT SIDED PLURAL EFFUSION, RUPTIUD LIVER ABCESS, CHD CONGENITAL HEART DISEASE, SCID/PCM, SEPSIS/RT SIDED CELLULITIS, FAILURE TO THRIVE, HEPATIC FAILURE, CHRONIC LIVER DISEASE, HIV COMPLICATION, HIE III/MENINGITIS, HYDROCEPHLOUS/MENINGITIS?, K/C OF DOWN SYNDROME+CHD, K/C OF SEIZURE DISORDER, CHD e BRONCHOPNEUMONIA, ACUTE MYOCARDITIS, MYOCARDITIS/BRONCHOPNEUMONIA?, CLD?, GAUCHER DISEASE e PLEURAL EFFUSION, NEPHROTIC SYNDROME/CCF?, PROTEIN CALORIE MALNUTRITION/SEPSIS?, PERI ORBITAL CELLULTIS, PNEUMOTHORAX, POSTENIOR FOSSA MASS IN BRAIN, RHEMATIC HEART DISEASE, SEPSIS/SJS, STATUS ASTHMATICUS, JOUBERT SYNDROME?, LT EVENTRATION OF DIAPHRAM.'
        return dept_text
    elif dept == 'MEDICAL UNIT II':
        dept_text = 'You’re on Medical Unit II, so the most likely Diagnosis should be among these : B 12 DEFICIENCY, ANEMIA, AFB TO GBS, AKI SEC TO AGE, ACUTE PANCREATITIS, AMOEBIC LIVER ABCESS, APLASTIC ANEMIA, ASPIRATION PNEUMONIA, ASTHAMA, AGE, BUDD CHAIR SYNDROME, CELLULITIS, CELLULITIS ON BOTH ARM, CHD E MEASLES E PNEUMONIA, CHD, CHIKEN POX, CHOLERA, BENZODIAZEPINE POISONING, APBPA/HIE, CELLULITIS OF RIGHT LEG & RIGHT FOREARM/BLEEDING DISORDER, CHD E PNEUMONIA, CHRONIC LIVER DISEASE, CKD, CKD GRADE 2, CKD/SLE, COMPLICATEDPNEUMONIA, CP CHILD, CP CHIL E PNEUMONIA, CP E SEIZURE DISORDER, DENGUE, DISSEMENATED TB, DOWN SYNDROME, DYSENTRY, EPILEPSY, ENCEPHALITIS, ENTERIC FEVER, FANCONE ANEMIA, FTT, FOOT GANGEROUS, FTT/SEPSIS, GASTROENTERITIS, GASTROENTERITIS BACTERIAL, HEMOLYTIC ANEMIA, HYPOCALEMIA, HEPATIC ENCEPHALOPATHY, HIE, HIV+BRONCHOPNEUMONIA, HSP, HYDROCEPHALOUS/MENINGITIS, HYPOCALEMIC FITS, HYPOCALEMIC PARALYSIS, HEMOPHILIA, K/C OF ALL, K/C OF AML, K/C OF CML, K/C OF RETINOBLASTOMA, K/C OF SSPE, LEFT SIDED CONGENITAL/DIAPHGMATIC HERBNIA/PNEUMONIA, LEFT SIDED EMPYEMA, LEFT SIDED PLUERAL EMPEYMA, LIVER ABSCESS/RIGHT PLUERAL EFFUSION, MALARIA, MENINGEOENCEPHALITIS, MENINGITIS, MYOCARDITIS, ORGANICPHOSPHARUS POISONING, PANCYTOPENIA, SUSP GLANZEMONN THROMBOSTHERIA, PME, PARASITIC TWIN/BED SORES GRADE 2, PCM, PCM/SEPSIS, PDA HIGH PRESSURE, PETRUSIS, PNEUMONIA, PHYORYGITIC, PLUERAL EMPYEMA, PLUERAL EFFUSION, MEASLES, MEASLES E PNEUMONIA, MEASLES COMPLICATED BY PNEUMONIA, MEASLES E COMPLICATION, POST MEASLES PNEUMONIA, POST MEASLES ENCEPHALITIS, PULMONARY HYPERTENSION, REACTIVE AIRWAY DISEASE, RDS, SEPSIS, SEPTIC SHOCK, SEVERE SEPSIS, SSPE, SNAKE BITE POISONING, RIGHT EMPYEMA 2 TO TB, RIGHT SIDED LOBAR PNEUMONIA, SAM (KWORSHIORKOR) E ACUTE GASTROENTERITIS, SICKLE THALESEMIA, SUSP DIPHTERIA, HLH, SEPTIC ARTHRITIS, SUSP ENTERIC, SUSP MENINGITIS, SUSP TESATOMA, SYNDROMIC, TB E PNEUMONIA, TB MENINGITIS, TB/URTI, TETANUS, TTP/MALARIA FALCIPARIM, TUBERCLOSIS, TUBERCLOSIS MENINGITIS, LEFT KNEE ARTHRITIS, UTI, CEREBRAL PALSY, SUSP CELIAC DISEASE, VIVAX MALARIA, SEIZURE DISORDER, VIRAL MENINGITIS, NON .'
        return dept_text
    elif dept == 'MEDICAL UNIT III':
        dept_text = 'You’re on Medical Unit III, co the most likely Diagnosis should be among these : AUTOIMUE DISORDER, CHD, CHRONIC SUPPURATIVE OTITIS MEDIA, CYSTIC FIBROSIS, CONGENITAL HEART DISEASE (CYANOTIC), DIARRHEA, DISSOCIATED DISORDER, ENTERIC FEVER, EMPYEMA, ERYTHEMA MUITIFORME, EARLY ONSET SEPSIS, HYPOVOLUMIC SHOCK, HYPOXIC ISCHEMIC ENCEPHALOPATHY, ITP, LEUKEMIA, LOW GRADE GLIOMA, LYMPHOPROLIFERATIVE DISORDER, malabsorption syndrome, METABOLIC FITS, MEASLES/ PNEUMONIA, MENINGOENCEPHALITIS, MENINGIOMYELOCELE, MECONIUM ASPIRATION SYNDROME, MICROCEPHALY, NEUROGENIC BLADDER, NEONATAL JAUNDICE, pleural effusion, PNEUMONIA, PRE B ALL, RESPIRAYORY AIR DISEASE, sepsis/septic shock, snake poisoning, STEVEN JOHNSON SYNDROME, TBM, typhoid, TORCH infection, TETANUS, UTI'
        return dept_text
    elif dept == 'NICU':
        dept_text = 'You work in the Neonatal ICU, so the most likely Diagnosis should be among these : LATE ONSET SEPSIS, RESPIRATORY DISTRESS SYNDROME, TRANSIENT TACHYPNEA OF NEW BORN, LBW'
        return dept_text
    elif dept == 'GASTRO':
        dept_text = 'You work in the Gastroenterology Unit'
        return dept_text
    else:
        dept_text = 'You work in pediatric oncology.'
        return dept_text

# — LLM setup —
df_training = pd.read_csv(
    'cleaned_unified_training_table.csv',
    parse_dates=["MR_REG_DATE", "MR_DOB", "VISIT_DATE"]
)
llm = OllamaLLM(model="deepseek-r1:7b")

SYSTEM_BASE = (
    "You are OPTIMUS, a personal healthcare assistant doctor. "
    "You will ONLY recommend what is asked for—top 5 diagnoses, top 5 lab requests and top 5 medications—and follow the department guidance: {} "
    "If you are less than 80% sure, suggest something outside the list; otherwise stick to it."
)

def build_prompts(dept_text: str):
    system = SystemMessagePromptTemplate.from_template(SYSTEM_BASE.format(dept_text))
    diag = ChatPromptTemplate.from_messages([
        system,
        HumanMessagePromptTemplate.from_template(
            "Recommend the TOP 5 possible DIAGNOSES for this patient only (ranked):\n\n{patient_data}"
        )
    ])
    lab = ChatPromptTemplate.from_messages([
        system,
        HumanMessagePromptTemplate.from_template(
            "Recommend the TOP 5 LAB REQUESTS for this patient only (ranked):\n\n{patient_data}"
        )
    ])
    med = ChatPromptTemplate.from_messages([
        system,
        HumanMessagePromptTemplate.from_template(
            "Recommend the TOP 5 MEDICATIONS for this patient only (ranked):\n\n{patient_data}"
        )
    ])
    return diag, lab, med

def clean_response(text: str) -> str:
    return re.sub(r'<think>.*?</think>', '', text, flags=re.DOTALL).strip()

def fetch_training_records(mr_code: str, visit_date: str) -> list:
    visit_dt = parse_visit_date(visit_date)
    sub = df_training[
        (df_training['MR_CODE'].astype(str) == str(mr_code)) &
        (df_training['VISIT_DATE'].dt.date == visit_dt)
    ]
    return sub[['MR_CODE', 'MR_SEX', 'AGE_AT_VISIT', 'PRESENTING_COMPLAIN']].to_dict(orient='records')





# — Flask routes —
@app.route('/add_user', methods=['POST'])
def add_user():
    data = request.json
    result = asyncio.run(add_user_async(
        data.get('name'), data.get('password'), data.get('email'),
        data.get('role', 'user'), data.get('department', 'General')
    ))
    return jsonify(result)

@app.route('/validate_user', methods=['POST'])
def validate_user():
    data = request.json
    result = asyncio.run(validate_user_async(data.get('password'), data.get('email')))
    if result and result.get('userid'):
        return jsonify({"status": "success", "user": result})
    return jsonify({"status": "failure", "message": "Invalid credentials"}), 401

@app.route('/delete_user', methods=['DELETE'])
def delete_user():
    data = request.json
    if not data.get('user_id'):
        return jsonify({"status": "failure", "message": "user_id is required"}), 400
    result = asyncio.run(delete_user_async(data['user_id']))
    status = 200 if result.get('status') == 'success' else 404
    return jsonify(result), status

@app.route('/recommend', methods=['POST'])
def recommend_route():
    data = request.json or {}
    print(data)
    try:
        # authenticate
        user = data.get('user')
        if not (isinstance(user, dict) and user.get('userid')):
            user = asyncio.run(validate_user_async(data.get('password', ''), data.get('email', '')))
        if not user:
            return jsonify({'status': 'failure', 'message': 'Invalid credentials'}), 401

        # patient data
        records = fetch_training_records(data.get('mr_code', ''), data.get('visit_date', ''))
        patient_data_str = json.dumps(records, default=str, indent=2)

        # build and call LLM prompts
        dept_text      = get_dept_text(user.get('department', ''))
        diag_p, lab_p, med_p = build_prompts(dept_text)

        diagnoses    = clean_response(llm.invoke(diag_p.format_prompt(patient_data=patient_data_str).to_messages()))
        lab_requests = clean_response(llm.invoke(lab_p.format_prompt(patient_data=patient_data_str).to_messages()))
        medications  = clean_response(llm.invoke(med_p.format_prompt(patient_data=patient_data_str).to_messages()))

        result = {
            'status':       'success',
            'diagnoses':    diagnoses,
            'lab_requests': lab_requests,
            'medications':  medications
        }
        payload = [result]

        # This will always produce a correct JSON array
        body = json.dumps(payload, default=str)
        app.logger.debug("RAW DUMPED JSON: %s", body)

        return Response(
            response=body,
            status=200,
            mimetype='application/json'
        )
    except Exception as e:
        traceback.print_exc()
        return jsonify({'status': 'error', 'message': str(e)}), 500


@app.route('/registration_records', methods=['GET'])
def registration_records_route():
    mr_code       = request.args.get('mr_code', '').strip()
    records = get_registration_records(mr_code)
    if not records:
        return jsonify(error="No records found."), 404
    return jsonify(records)

@app.route('/presenting_complain_records', methods=['GET'])
def presenting_complain_records_route():
    mr_code       = request.args.get('mr_code', '').strip()
    visit_date    = request.args.get('visit_date', '').strip()
    records = get_presenting_complain_records(mr_code, visit_date)
    if not records:
        return jsonify(error="No records found."), 404
    return jsonify(records)

@app.route('/vitals_records', methods=['GET'])
def vitals_records_route():
    mr_code = request.args.get('mr_code', '').strip()
    visit_date = request.args.get('visit_date', '').strip()
    records = get_vitals_records(mr_code, visit_date)
    if not records:
        return jsonify(error="No records found."), 404
    return jsonify(records)

@app.route('/diagnoses_records', methods=['GET'])
def diagnoses_records_route():
    mr_code = request.args.get('mr_code', '').strip()
    visit_date = request.args.get('visit_date', '').strip()
    records = get_diagnoses_records(mr_code, visit_date)
    if not records:
        return jsonify(error="No records found."), 404
    return jsonify(records)

@app.route('/lab_request_records', methods=['GET'])
def lab_request_records_route():
    mr_code = request.args.get('mr_code', '').strip()
    visit_date = request.args.get('visit_date', '').strip()
    records = get_lab_request_records(mr_code, visit_date)
    if not records:
        return jsonify(error="No records found."), 404
    return jsonify(records)

@app.route('/lab_result_records', methods=['GET'])
def lab_result_records_route():
    mr_code = request.args.get('mr_code', '').strip()
    visit_date = request.args.get('visit_date', '').strip()
    records = get_lab_result_records(mr_code, visit_date)
    if not records:
        return jsonify(error="No records found."), 404
    return jsonify(records)

@app.route('/medication_records', methods=['GET'])
def medication_records_route():
    mr_code = request.args.get('mr_code', '').strip()
    records = get_medication_records(mr_code)
    if not records:
        return jsonify(error="No records found."), 404
    return jsonify(records)




if __name__ == '__main__':
    app.run(debug=True)
