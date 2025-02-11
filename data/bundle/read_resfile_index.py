import csv

def read_resfile_index(resfile_index_file) -> dict[str, str]:
    index = {}
    with open(resfile_index_file, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        for row in reader:
            index[row[0]] = row[1]
    return index
