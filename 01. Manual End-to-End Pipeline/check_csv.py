import csv
from pathlib import Path

csv_file = next(Path("data").glob("Exercise Entries*.csv"))

with csv_file.open(
    "r",
    encoding="utf-8-sig",
    newline=""
) as file:
    reader = csv.reader(file)
    header = next(reader)
    count = sum(1 for row in reader)

print("Source columns:", len(header))
print("Source records:", count)