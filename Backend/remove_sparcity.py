import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np

# 1) Load the dataset
df = pd.read_csv('unified_training_table.csv')

# 2) Basic missing‐value fill for all columns except LAB_RESULTS
for col in df.columns:
    if col == 'LAB_RESULTS':
        continue
    if df[col].dtype == 'object':
        df[col] = df[col].fillna('Unknown')
    else:
        df[col] = df[col].fillna(df[col].median())

# 3) Split into rows with and without LAB_RESULTS (use .copy() to avoid pandas warnings)
df_with_lab = df.loc[df['LAB_RESULTS'].notnull()].copy()
df_without_lab = df.loc[df['LAB_RESULTS'].isnull()].copy()


# 4) Build a combined text feature for similarity matching
def combine_features(row):
    parts = [
        str(row['DIAGNOSIS']),
        str(row['PRESENTING_COMPLAIN']),
        str(row['FINAL_DIAGNOSIS'])
    ]
    # drop 'Unknown' placeholders and empty strings
    return " ".join(p for p in parts if p and p != 'Unknown').strip()


df_with_lab['combined'] = df_with_lab.apply(combine_features, axis=1).astype(str)
df_without_lab['combined'] = df_without_lab.apply(combine_features, axis=1).astype(str)

# 5) Fallback logic if there are no examples to match against
if df_with_lab.empty:
    print("⚠️  No existing LAB_RESULTS to copy from; filling all with default placeholder.")
    df['LAB_RESULTS'] = df['LAB_RESULTS'].fillna("No Lab Results Recorded")
else:
    # 6) Remove any truly empty combined rows before vectorizing
    df_with_lab = df_with_lab[df_with_lab['combined'] != ""]
    if df_with_lab.empty:
        # Edge case: there were LAB_RESULTS, but none had any text to match on
        print("⚠️  LAB_RESULTS exist but no matching text fields; using placeholder instead.")
        df['LAB_RESULTS'] = df['LAB_RESULTS'].fillna("No Lab Results Recorded")
    else:
        # 7) Vectorize and compute nearest‐neighbor similarity
        vectorizer = TfidfVectorizer()
        X_with = vectorizer.fit_transform(df_with_lab['combined'])
        X_without = vectorizer.transform(df_without_lab['combined'])

        # 8) For each missing row, find the most similar existing row and copy its LAB_RESULTS
        filled = []
        for i in range(X_without.shape[0]):
            sims = cosine_similarity(X_without[i], X_with).ravel()
            idx = np.argmax(sims)
            filled.append(df_with_lab.iloc[idx]['LAB_RESULTS'])

        # 9) Write the filled values back into the original dataframe
        df.loc[df['LAB_RESULTS'].isnull(), 'LAB_RESULTS'] = filled

# 10) Save the final cleaned dataset
output_path = 'cleaned_filled_unified_training_table.csv'
df.to_csv(output_path, index=False)
print(f"✔ Cleaning complete. Saved to {output_path}")
