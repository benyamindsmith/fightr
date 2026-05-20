import os
import pandas as pd
import pyreadr

# URLs
ultimate_ufc_url = "https://raw.githubusercontent.com/shortlikeafox/ultimate_ufc_dataset/refs/heads/main/ufc-master.csv"
ufc_rankings_url = "https://raw.githubusercontent.com/martj42/ufc_rankings_history/refs/heads/master/rankings_history.csv"

# Output folder
data_dir = "data"
os.makedirs(data_dir, exist_ok=True)

# Output paths
ultimate_ufc_csv_path = os.path.join(data_dir, "ultimate_ufc_dataset.csv")
ufc_rankings_csv_path = os.path.join(data_dir, "ufc_rankings_dataset.csv")

ultimate_ufc_rdata_path = os.path.join(data_dir, "ultimate_ufc_dataset.RData")
ufc_rankings_rdata_path = os.path.join(data_dir, "ufc_rankings_dataset.RData")

# Read data
ultimate_ufc_dataset = pd.read_csv(ultimate_ufc_url)
ufc_rankings_dataset = pd.read_csv(ufc_rankings_url)

# Save as CSV
ultimate_ufc_dataset.to_csv(ultimate_ufc_csv_path, index=False)
ufc_rankings_dataset.to_csv(ufc_rankings_csv_path, index=False)

# Save as RData
pyreadr.write_rdata(
    ultimate_ufc_rdata_path,
    ultimate_ufc_dataset,
    df_name="ultimate_ufc_dataset"
)

pyreadr.write_rdata(
    ufc_rankings_rdata_path,
    ufc_rankings_dataset,
    df_name="ufc_rankings_dataset"
)

print("Files saved successfully.")
