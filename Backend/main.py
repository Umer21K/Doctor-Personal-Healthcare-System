import pandas as pd

# 1. Read source CSVs (adjust filenames/paths as needed)
reg   = pd.read_csv("mr_registiration.csv",
                    parse_dates=['MR_REG_DATE', 'MR_DOB'])
pres  = pd.read_csv("presinting_complain.csv",
                    parse_dates=['MR_VISIT_DATE'])
vitals= pd.read_csv("vitals.csv",
                    parse_dates=['MR_VISITDATE', 'VITAL_DATE'])
diag  = pd.read_csv("Diagnosis.csv",
                    parse_dates=['MR_VISIT_DATE', 'MR_DATE_TIME'])
lr    = pd.read_csv("lab_request.csv",
                    parse_dates=['MR_VISIT_DATE'])
lres  = pd.read_csv("LAB_RRESULT_ENTERY.csv",
                    parse_dates=['INSERT_DT'],
                    low_memory=False)
med   = pd.read_csv("medication.csv",
                    parse_dates=['INSERT_DT'],
                    low_memory=False)

# 2. Normalize key types so merges won’t fail
for df_source in (reg, pres, vitals, diag, lr, med):
    df_source['MR_CODE'] = df_source['MR_CODE'].astype(str)

lr['LRS_NO']   = lr['LRS_NO'].astype(str)
lres['LRS_NO'] = lres['LRS_NO'].astype(str)

# 3. Base merge: registration + presenting complaint
df = (
    pres.merge(reg, on='MR_CODE', how='left')
        .rename(columns={'MR_VISIT_DATE': 'VISIT_DATE'})
)
df['AGE_AT_VISIT'] = ((df['VISIT_DATE'] - df['MR_DOB']).dt.days / 365.25).round(1)

# 4. Merge vitals
vitals = vitals.rename(columns={
    'MR_VISITDATE':'VISIT_DATE',
    'VITAL_BP_SIS':'BP_SYSTOLIC',
    'VITAL_DYS':'BP_DIASTOLIC',
    'VITAL_TEMP':'TEMP',
    'VITAL_PULSE':'PULSE',
    'VITAL_RES_RATE':'RESP_RATE',
    'VITAL_HEIGHT':'HEIGHT',
    'VITAL_WEIGHT':'WEIGHT',
    'VITAL_O2_SAT':'O2_SAT',
    'VITAL_PAIN':'PAIN_SCORE'
})
df = df.merge(
    vitals[['MR_CODE','VISIT_DATE',
            'BP_SYSTOLIC','BP_DIASTOLIC','TEMP','PULSE',
            'RESP_RATE','HEIGHT','WEIGHT','O2_SAT','PAIN_SCORE']],
    on=['MR_CODE','VISIT_DATE'], how='left'
)

# 5. Merge diagnoses
diag = diag.rename(columns={'MR_VISIT_DATE':'VISIT_DATE'})
df = df.merge(
    diag[['MR_CODE','VISIT_DATE',
          'MED_REC_DIAG','MED_REC_FIAN_DIAG',
          'MED_REC_SUM_REMARKS','MED_REC_NEXT_PLN_CODE']],
    on=['MR_CODE','VISIT_DATE'], how='left'
).rename(columns={
    'MED_REC_DIAG':'DIAGNOSIS',
    'MED_REC_FIAN_DIAG':'FINAL_DIAGNOSIS',
    'MED_REC_SUM_REMARKS':'REMARKS',
    'MED_REC_NEXT_PLN_CODE':'NEXT_PLAN'
})

# 6. Aggregate lab requests
lr_group = (
    lr
    .groupby(['MR_CODE','MR_VISIT_DATE'])['LAB_TEST']
    .agg(lambda x: '; '.join(x.dropna().astype(str)))
    .reset_index()
    .rename(columns={'MR_VISIT_DATE':'VISIT_DATE',
                     'LAB_TEST':'LAB_REQUESTS'})
)

# 7. Combine lab requests with results, then aggregate
lres_comb = (
    lr.merge(lres, on='LRS_NO', how='left', suffixes=('_REQ','_RES'))
      .assign(LAB_TEST_REQ=lambda d: d['LAB_TEST_REQ'].astype(str))
)
lres_comb['RESULT_STR'] = lres_comb.apply(
    lambda row: f"{row['LAB_TEST_REQ']}:{row['PARAMETER']}={row['RESULT']}"
                if pd.notna(row['PARAMETER']) and pd.notna(row['RESULT'])
                else None,
    axis=1
)
lres_group = (
    lres_comb
    .groupby(['MR_CODE','MR_VISIT_DATE'])['RESULT_STR']
    .agg(lambda x: '; '.join(x.dropna().astype(str)))
    .reset_index()
    .rename(columns={'MR_VISIT_DATE':'VISIT_DATE',
                     'RESULT_STR':'LAB_RESULTS'})
)

df = df.merge(lr_group, on=['MR_CODE','VISIT_DATE'], how='left')
df = df.merge(lres_group, on=['MR_CODE','VISIT_DATE'], how='left')

# 8. Aggregate medications
# Ensure MR_REG_DT_TIME is datetime
med['MR_REG_DT_TIME'] = pd.to_datetime(med['MR_REG_DT_TIME'], errors='coerce')
med['VISIT_DATE']     = med['MR_REG_DT_TIME'].dt.floor('d')

def format_med(group):
    return '; '.join(
        f"{row['ITEM_NAME']}|{row['DOSAGE']}|{row['INT_CODE']}"
        for _, row in group.iterrows()
        if pd.notna(row['ITEM_NAME'])
    )

# **Group only on the detail columns** to avoid the deprecation warning
med_series = (
    med
    .groupby(['MR_CODE','VISIT_DATE'])[['ITEM_NAME','DOSAGE','INT_CODE']]
    .apply(format_med)
)
med_group = med_series.to_frame('MEDICATIONS').reset_index()

# Merge meds into main DF
df['VISIT_DATE']       = pd.to_datetime(df['VISIT_DATE'])
med_group['VISIT_DATE'] = pd.to_datetime(med_group['VISIT_DATE'])
df = df.merge(med_group, on=['MR_CODE','VISIT_DATE'], how='left')

# 9. Reorder & export
final_cols = [
    'MR_CODE','MR_REG_DATE','MR_SEX','MR_DOB','VISIT_DATE','AGE_AT_VISIT',
    'PRESENTING_COMPLAIN','PRE_COM_DURATION',
    'BP_SYSTOLIC','BP_DIASTOLIC','TEMP','PULSE','RESP_RATE',
    'HEIGHT','WEIGHT','O2_SAT','PAIN_SCORE',
    'DIAGNOSIS','FINAL_DIAGNOSIS','REMARKS','NEXT_PLAN',
    'LAB_REQUESTS','LAB_RESULTS','MEDICATIONS'
]
unified_df = df[final_cols]
unified_df.to_csv("unified_training_table.csv", index=False)

print("✅ unified_training_table.csv generated successfully.")
