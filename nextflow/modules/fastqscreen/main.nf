#!/usr/bin/env nextflow

/*
    FastQ Screen module: quality check for contamination against reference genomes.
*/

process FASTQSCREEN {
    tag "FASTQ Screen on $sample_id"
    publishDir "${params.qc_fastqscreen}", mode: 'copy'

    input:
    tuple val(sample_id), path(read1), path(read2)
    path database  // folder that contains fastq_screen.conf and the indices

    output:
    path "fastqscreen_${sample_id}_result", emit: logs_FQS

    script:
    """
    mkdir fastqscreen_${sample_id}_result
    
    # Store absolute paths before changing directory
    WORK_DIR=\$(pwd)
    OUTPUT_DIR="\${WORK_DIR}/fastqscreen_${sample_id}_result"
    READ1_PATH="\${WORK_DIR}/${read1}"
    READ2_PATH="\${WORK_DIR}/${read2}"
    
    cd ${database}
    fastq_screen \\
        --conf fastq_screen.conf \\
        --aligner bowtie2 \\
        --threads ${task.cpus} \\
        --outdir "\${OUTPUT_DIR}" \\
        "\${READ1_PATH}" "\${READ2_PATH}"
    """
}

