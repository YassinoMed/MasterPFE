import os
import tarfile

support_pack_dir = "support-pack"
dest_dir = "real-data"
os.makedirs(dest_dir, exist_ok=True)

targets = [
    "events.txt",
    "kyverno-policyreports.yaml",
    "falco-rules-validation.log",
    "production-runtime-evidence.md",
    "kyverno-runtime-report.md"
]

for filename in os.listdir(support_pack_dir):
    if filename.endswith(".tar.gz"):
        tar_path = os.path.join(support_pack_dir, filename)
        archive_name = filename[:-7] # remove .tar.gz
        try:
            with tarfile.open(tar_path, "r:gz") as tar:
                for member in tar.getmembers():
                    member_basename = os.path.basename(member.name)
                    if member_basename in targets:
                        # Extract and prefix with archive name
                        f = tar.extractfile(member)
                        if f:
                            out_name = f"{archive_name}_{member_basename}"
                            out_path = os.path.join(dest_dir, out_name)
                            with open(out_path, "wb") as out_file:
                                out_file.write(f.read())
                            print(f"Extracted {member.name} to {out_path}")
        except Exception as e:
            print(f"Error reading {filename}: {e}")
