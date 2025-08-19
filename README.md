# CRUK Scotland Institute Workflow Wizard: sci_wiz

sci_wiz packages Nextflow framework and Python's modular approach under the hood to deliver easy-to-use functionalities for RNA-Seq data pre-processing using standard and widely accepted tools. The package is designed to install all the dependencies required to run the workflow so that you do not have to install them separately.

> [!NOTE]
> You will need to download the STAR index, reference genome, and annotation files separately. The package will not download these files for you.

# README (add‑fastqscreen‑module branch)

A practical, biologist‑friendly manual for running the *sci‑wiz* RNA‑seq preprocessing pipeline on the **add‑fastqscreen‑module** branch. This guide assumes no prior experience with Nextflow.

---

## 1) What this pipeline does

End‑to‑end preprocessing for bulk RNA‑seq:

* **QC of raw reads**: FastQC; **FastQ Screen** to check for contamination; MultiQC report.
* **Optional trimming**: fastp.
* **Alignment**: STAR.
* **Quantification**: featureCounts (+ strandedness inference with RSeQC).
* **Compression**: BAM → CRAM to save space.

You can run just the initial QC, or the full preprocessing workflow.

---

## 2) Requirements at a glance

* **Operating system**: Linux shell (local VM/desktop or an HPC login node).
* **Nextflow**: v23+ available on your system (ask IT or use your module system).
* **Container engine**: either **Singularity/Apptainer** or **Docker**.
* **Scheduler** (HPC only): **Slurm**.
* **Reference data** you already have (or can obtain from your group):

  * STAR genome index directory (75bp or 150bp build used in the lab).
  * Reference genome FASTA.
  * Gene annotation **GTF**.
  * Gene annotation **BED** (for strandedness check).
  * **FastQ Screen** configuration file (**fastq\_screen.conf**) and the Bowtie2 indices it references.

> Tip: For large STAR runs, increase open files limit once per session: `ulimit -n 3000`.

---

## 3) Install the CLI (one‑time)

It’s easiest to use a small Python virtual environment and install the CLI.

```bash
# 3A. Create & activate a virtual environment
python -m venv .sci_wiz && source .sci_wiz/bin/activate

# 3B. Install the package (choose one):
#    Option 1 — From a prebuilt wheel (if provided by your team)
pip install sci_wiz-<version>-py3-none-any.whl

#    Option 2 — From source (inside the repository checkout)
pip install .

# 3C. Sanity check
sci_wiz --help
```

> If your HPC uses **Poetry**, `poetry install` then run commands as `poetry run sci_wiz …`.

---

## 4) Make your user config (per project)

Generate a template, then edit it with your project’s paths:

```bash
sci_wiz create-config
# creates: user_input.ini in your current directory
```

Open **user\_input.ini** and fill the values. Minimal example (edit paths):

```ini
[USER_INPUT]
project_name = G123_2508_myRun           # any short, descriptive name
profile      = hpc                       # "vm" for a laptop/VM; "hpc" for a cluster
reads        = /data/OMICS/proj/*/*_{R1,R2}_001.fastq.gz
output_dir   = /data/OMICS/proj/Data/    # a base folder; the pipeline appends project_name
index        = /refs/STAR_150bp
annotation   = /refs/genes.gtf
reference    = /refs/genome.fa
annotation_bed = /refs/genes.bed
fastqscreen_conf = /refs/fastq_screen.conf
batch_info   = false                     # true only if you need to concatenate two runs
run1 =
run2 =
batch_destination =

[TRIMMING]
trim_front_read_01 = 1
trim_front_read_02 = 1
trim_tail_read_01  = 0
trim_tail_read_02  = 0
```

**Profiles**:

* **vm** = runs locally and uses your chosen container engine directly.
* **hpc** = submits a Slurm job under the hood and monitors it for you.

**Batch merging (optional)**:

* If the same samples were sequenced in two separate runs, set `batch_info = true` and define `run1`, `run2`, and `batch_destination`. The pipeline will concatenate matching FASTQs into the destination before processing.

---

## 5) Check Nextflow & container engine

```bash
# Check nextflow version detected by the wrapper
sci_wiz check-nf-version

# Choose the container engine at runtime with --engine
#   singularity (HPC default) or docker (VM/desktop)
```

**HPC users**: ensure the login node has `module load nextflow` and `module load singularity` available, or that both are on your `$PATH`.

---

## 6) Run **Initial QC only** (FastQC + FastQ Screen + MultiQC)

Good for a quick look at new data before alignment.

```bash
# On HPC with Singularity (recommended)
sci_wiz run-initial-qc --config user_input.ini --engine singularity

# On a VM/desktop with Docker
sci_wiz run-initial-qc --config user_input.ini --engine docker
```

**Outputs** will appear under your `output_dir/project_name/` in subfolders like:

* `QC/Fastqc/…`
* `QC/Fastqscreen/…`
* `QC/Multiqc/multiqc_report.html`

> If the FastQ Screen results folder doesn’t appear, see **Appendix A** (known quirks) about setting `qc_fastqscreen`.

---

## 7) Run the **full preprocessing**

This performs trimming (unless you’ve already decided to skip it), QC, STAR alignment, featureCounts, MultiQC and BAM→CRAM.

```bash
# HPC + Singularity
sci_wiz run-preprocessing --config user_input.ini --engine singularity

# VM + Docker
sci_wiz run-preprocessing --config user_input.ini --engine docker
```

The wrapper writes a Nextflow params JSON, launches the pipeline, and for **HPC** submits a Slurm job. You’ll see live status messages; on HPC the job name starts with `nf-parent`.

---

## 8) Where to find your results

Inside `output_dir/project_name/`:

* **QC**

  * `QC/Fastp/` — fastp HTML & JSON (if trimming enabled)
  * `QC/Fastqc/` — FastQC per sample
  * `QC/Fastqscreen/` — FastQ Screen per sample
  * `QC/Multiqc/multiqc_report.html` — combined report
* **Alignment**

  * `Bams/<sample>.bam` — coordinate‑sorted STAR BAM
  * `QC/Alignment_Info/` — STAR `Log.final.out`, splice junctions, etc.
* **Counts**

  * `Feature_Counts/<project>_raw_counts_fc.tsv` — gene counts table
  * `Feature_Counts/<project>_raw_counts_meta_fc.txt` — featureCounts summary
* **CRAM**

  * `Crams/<sample>.cram` — compressed alignment

> File names and exact destinations are set by the pipeline; MultiQC will automatically pick up most outputs.

---

## 9) Tuning & advanced usage

* **Trimming**: Initial QC mode *bypasses* trimming. In full runs, trimming is **on** by default. You can adjust the four trimming parameters in `[TRIMMING]`.
* **Resources**: Per‑step CPU/memory/containers are defined for both VM and HPC profiles. If your HPC policy requires different queues/partitions, your admin can adjust the profile settings once for everyone.
* **Container engine**: Pick `--engine singularity` or `--engine docker`. The pipeline selects compatible container images automatically.
* **Resuming**: The wrapper runs Nextflow with `-resume`, so you can safely re‑run after fixing a path or parameter without redoing work.

---

## 10) Troubleshooting

* **“Non‑zero exit status”**: Check `.nextflow.log` in your working directory for details. Then re‑run; cached steps will be skipped.
* **Slurm submission failure (HPC)**: You’ll see a clear error message. Confirm you can run `sbatch` on your login node and have access to the correct partition.
* **FastQ Screen errors**: Ensure `fastqscreen_conf` points to a readable file and that the Bowtie2 index paths inside it are correct.
* **STAR “Too many open files”**: Run `ulimit -n 3000` before launching.
* **Wrong profile**: If you’re on a laptop/VM, set `profile = vm` in `user_input.ini`. On HPC, set `profile = hpc`.

---

## 11) Quick recipes

* **QC only on a VM**

  ```bash
  sci_wiz run-initial-qc --config user_input.ini --engine docker
  ```
* **Full run on HPC**

  ```bash
  sci_wiz run-preprocessing --config user_input.ini --engine singularity
  ```
* **Check versions**

  ```bash
  sci_wiz version
  sci_wiz check-nf-version
  ```

---

## Appendix A — How the wrapper works (for the curious)

* The `sci_wiz` command:

  * writes your edited `user_input.ini` into a JSON file consumed by Nextflow,
  * chooses the right profile (`vm` or `hpc`) and container engine,
  * triggers Nextflow locally (**vm**) or via a generated Slurm script (**hpc**),
  * uses `-resume` so re‑runs are incremental.

This keeps the heavy lifting in Nextflow while giving you a single, simple CLI.

---

## FastQ Screen: config file (`fastq_screen.conf`)

**What the pipeline expects**

* You provide a path to a FastQ Screen config file in your `user_input.ini` as `fastqscreen_conf` (this key is written by `sci_wiz configure`). The Nextflow module calls `fastq_screen` with `--conf ${params.fastqscreen_conf} --aligner bowtie2 --threads ${task.cpus}` and writes results to a run-specific folder, e.g. `fastqscreen_<sample>_result`. No other options are read from the pipeline — so the conf file only needs to describe the Bowtie2 databases you want to screen against.

**Minimal contents of the conf file**
Use the standard FastQ Screen format that maps a label to a Bowtie2 index basename. A lab-specific skeleton could look like:

```text
# Example entries — replace with real paths to your Bowtie2 indices
# DATABASE yeast   /refs/bowtie2/yeast/yeast
# DATABASE mouse   /refs/bowtie2/mouse/GRCm39
# DATABASE human   /refs/bowtie2/human/GRCh38
```

Because the FASTQ Screen process sets `--aligner bowtie2` itself, your indices must be Bowtie2-builds. Ensure these paths are visible inside the container on your platform (profiles set Docker/Singularity containers; Singularity autofs mounts are enabled).

**QC/Fastqscreen folder (current behaviour)**
As of 2025‑08‑19 on branch **add‑fastqscreen‑module**, the pipeline defines a default publish directory for FastQ Screen in `main.nf`:

```groovy
params.qc_fastqscreen = "${params.output_dir}/QC/Fastqscreen"
```

The FastQ Screen process publishes there by default, and its output is now labelled with `emit: logs_FQS`. The QC subworkflow consumes this labelled output for MultiQC aggregation. No extra parameters are needed from users; the folder will appear automatically.

---

## Run the Nextflow pipeline directly (skip the `sci_wiz` CLI)

If you prefer not to use the Python wrapper/CLI, you can run the Nextflow pipeline yourself. Below mirrors what the wrapper does under the hood (profile + container engine + `-params-file` + optional `-entry`).

### 1) Create a `params.json`

Prepare a JSON file with the keys that the pipeline reads. Fill in absolute paths appropriate for your system:

```json
{
  "project_name": "G123_2508_demo",
  "reads": "/data/PROJECT/*/*_{R1,R2}_001.fastq.gz",
  "output_dir": "/data/PROJECT/Data/G123_2508_demo",
  "index": "/refs/STAR_75bp_or_150bp",
  "annotation": "/refs/Org.OrgCode.110.gtf",
  "reference": "/refs/Org.OrgCode.110.fa",
  "annotation_bed": "/refs/Org.OrgCode.110.bed",
  "getStrand": "/path/to/getstrand.py",
  "cleanCount": "/path/to/cleancount.py",
  "batch_info": false,
  "run1": "",
  "run2": "",
  "dest": "",
  "initial_qc": false,
  "trim_front_read_01": 1,
  "trim_front_read_02": 1,
  "trim_tail_read_01": 0,
  "trim_tail_read_02": 0,
  "multiqc_config": "/path/to/nextflow/multiqc",
  "fastqscreen_conf": "/path/to/fastq_screen.conf",
}
```

Keys consumed by the workflow and modules are shown in `nextflow/main.nf` and the QC subworkflow. No `qc_fastqscreen` key is required; the pipeline sets the publish directory by default.

### 2) Run Nextflow

**On a VM/workstation** (choose docker or singularity):

```bash
# with Singularity containers
nextflow run nextflow/main.nf \
  -c nextflow/nextflow.config \
  -profile vm,singularity \
  -params-file params.json \
  -resume

# or with Docker containers
nextflow run nextflow/main.nf \
  -c nextflow/nextflow.config \
  -profile vm,docker \
  -params-file params.json \
  -resume
```

These flags mirror the wrapper’s command line.

**On HPC (Slurm)**:

```bash
nextflow run nextflow/main.nf \
  -c nextflow/nextflow.config \
  -profile hpc,singularity \
  -params-file params.json \
  -resume
```

The `hpc` profile in `nextflow.config` assigns Slurm executors and suitable container images/resources to each process. Load `nextflow` and `singularity` per your site setup.

### 3) Run *only* the initial QC

The pipeline exposes a `rawQc` workflow that performs trimming (unless `initial_qc=true`), FastQC and FastQ Screen, with MultiQC if `initial_qc=true`. You can target it directly with `-entry`:

```bash
nextflow run nextflow/main.nf \
  -c nextflow/nextflow.config \
  -profile vm,singularity \
  -params-file params.json \
  -entry rawQc \
  -resume
```

This is exactly how the CLI’s `run-initial-qc` subcommand invokes Nextflow.

### Outputs you should see

* `QC/Fastqc/` (FastQC zips/HTML) and `QC/Fastp/` if trimming ran; `QC/Multiqc/` with `multiqc_report.html`; `QC/Fastqscreen/`. Defaults for all except FastQ Screen are set in `main.nf`.


---


### Trimming raw data

The [Illumina Stranded library preparation kit](https://emea.illumina.com/products/by-type/sequencing-kits/library-prep-kits/stranded-mrna-prep.html) is used as the default kit. This kit requires trimming of the first base from both reads. The settings for this are the default in the *user_input.ini* file. **If you are using a different library preparation kit, the trimming parameters may be different.** Please check the documentation for your kit. If the kit requires different trimming or if you want to switch off trimming, you can do this by editing the *user_input.ini* file. The workflow uses [FastP](https://github.com/OpenGene/fastp) and the *user_input.ini* file uses the same flags as FastP but for a controlled set of parameters. The following command will just run the initial QC step, not trimming:

```console
sci_wiz run-initial-qc
```


## Report issues

If you find any issues with our code, you can reach out to us by:

* Reporting Issues: If you encounter any issues or bugs, please create a detailed issue report on the repository.

* Providing Feedback: Share your feedback on existing features or suggest improvements.

* Documentation Edits: If you find any discrepancies or have suggestions for improving the documentation, feel free to submit edits or open an issue.



## Citation

If you find *sci_wiz* useful in your research, please consider citing it:

```bibtex
@software{
    sci_wiz,
    author = {Jayaraman, Siddharth and Ojo, Ifedayo and Sikarwar, Mayank and Kwan, Ryan and Shaw, Robin and Miller, Crispin},
    month = {8},
    title = {CRUK Scotland Institute Workflow Wizard: sci_wiz},
    url = {https://github.com/Beatson-CompBio/RNA-seq-workflow},
    year = {2025}
    }
```

### How to cite dependencies?

We will really appreciate if you could also cite the dependencies using this [bib file](./Documentation/dependencies.bib):

* Nextflow
* Bamtools
* FeatureCounts
* Fastp
* STAR
* Multiqc
