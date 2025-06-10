import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np

df = pd.read_csv('unified_training_table.csv')

for col in df.columns:
    if col == 'LAB_RESULTS':
        continue
    if df[col].dtype == 'object':
        df[col] = df[col].fillna('Unknown')
    else:
        df[col] = df[col].fillna(df[col].median())

df_with_lab = df.loc[df['LAB_RESULTS'].notnull()].copy()
df_without_lab = df.loc[df['LAB_RESULTS'].isnull()].copy()


def combine_features(row):
    parts = [
        str(row['DIAGNOSIS']),
        str(row['PRESENTING_COMPLAIN']),
        str(row['FINAL_DIAGNOSIS'])
    ]

    return " ".join(p for p in parts if p and p != 'Unknown').strip()


df_with_lab['combined'] = df_with_lab.apply(combine_features, axis=1).astype(str)
df_without_lab['combined'] = df_without_lab.apply(combine_features, axis=1).astype(str)

if df_with_lab.empty:
    print("  No existing LAB_RESULTS to copy from; filling all with default placeholder.")
    df['LAB_RESULTS'] = df['LAB_RESULTS'].fillna("No Lab Results Recorded")
else:

    df_with_lab = df_with_lab[df_with_lab['combined'] != ""]
    if df_with_lab.empty:

        print("  LAB_RESULTS exist but no matching text fields; using placeholder instead.")
        df['LAB_RESULTS'] = df['LAB_RESULTS'].fillna("No Lab Results Recorded")
    else:

        vectorizer = TfidfVectorizer()
        X_with = vectorizer.fit_transform(df_with_lab['combined'])
        X_without = vectorizer.transform(df_without_lab['combined'])

        filled = []
        for i in range(X_without.shape[0]):
            sims = cosine_similarity(X_without[i], X_with).ravel()
            idx = np.argmax(sims)
            filled.append(df_with_lab.iloc[idx]['LAB_RESULTS'])


        df.loc[df['LAB_RESULTS'].isnull(), 'LAB_RESULTS'] = filled

output_path = 'cleaned_filled_unified_training_table.csv'
df.to_csv(output_path, index=False)
print(f"✔ Cleaning complete. Saved to {output_path}")
