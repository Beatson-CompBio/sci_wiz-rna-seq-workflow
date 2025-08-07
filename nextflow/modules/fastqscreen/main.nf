#!/usr/bin/env nextflow

/*
    FastQ Screen module: quality check for contamination against reference genomes.
*/

process FASTQSCREEN {
    tag "FASTQ Screen on $sample_id"
    publishDir "${params.qc_fastqscreen}", mode: 'copy'

    input:
    tuple val(sample_id), path(reads), path(fastqscreen_conf)

    output:
    path "fastqscreen_${sample_id}_result", emit: logs_FQS

    script:
    """
    mkdir fastqscreen_${sample_id}_result
    fastq_screen \\
        --conf ${fastqscreen_conf} \\
        --aligner bowtie2 \\
        --threads ${task.cpus} \\
        --outdir fastqscreen_${sample_id}_result \\
        ${reads}
    """
}

