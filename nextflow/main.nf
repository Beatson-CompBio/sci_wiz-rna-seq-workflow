#!/usr/bin/env nextflow

/*
	This a bulk RNA preprocessing workflow.
	This workflow will be invoking processess from the modules folder
	Its configuration is handled by nextflow.config file
*/

// Declare the pipeline parameters
params.project_name = "G12_uniqueName"
params.reads = "$projectDir/Data/*{R1,R2}_001.fastq.gz"
params.index = "$projectDir/Mouse_39.110_STAR_75bp"
params.annotation = "$projectDir/Mus_musculus_GeneAnnot.GRChm39.110.gtf"
params.multiqc_config = "$projectDir/multiqc"
params.reference = "$projectDir/Mus_musculus_Genome.GRChm39.110.fa"
params.annotation_bed = "$projectDir/Mus_musculus_GeneAnnot.GRChm39.110.bed"
params.getStrand = "$projectDir/getstrand.py"
params.cleanCount = "$projectDir/cleancount.py"
params.output_dir = ""
params.run1 = "/Nextflow_Project/Data/run_01"
params.run2 = "/Nextflow_Project/Data/run_01"
params.dest = "$projectDir/run"
params.batch_info = false
params.initial_qc = false
params.trim_front_read_01 = 1
params.trim_front_read_02 = 1
params.trim_tail_read_01 = 0
params.trim_tail_read_02 = 0

//directories
params.bam_dir = "${params.output_dir}/Bams"
params.cram_dir = "${params.output_dir}/Crams"
params.trimmed = "${params.output_dir}/Fastq_Trimmed"
params.feature_count_dir = "${params.output_dir}/Feature_Counts"
params.qc_alignment = "${params.output_dir}/QC/Alignment_Info"
params.qc_fastp = "${params.output_dir}/QC/Fastp"
params.qc_fastqc = "${params.output_dir}/QC/Fastqc"
params.qc_multiqc = "${params.output_dir}/QC/Multiqc"
params.qc_fastqscreen = "${params.output_dir}/QC/Fastqscreen"

// grab the read file for the channel factor based on batch_info 'params.batch_info'
reads = params.batch_info ? "$params.dest/*{R1,R2}_001.fastq.gz" : params.reads

// import subworkflows 
include { setup } from './subworkflows/concatBatchRun'
include { rnaSeq } from './subworkflows/rnaseqPreprocess'
include { rawQc } from './subworkflows/qualityCheck'

//default entry point
workflow {
        // create input channels
        index_ch = channel.fromPath(params.index, checkIfExists: true)
        annotation_ch = channel.fromPath(params.annotation, checkIfExists: true)
        reference_ch = channel.fromPath(params.reference, checkIfExists: true)
        bed_ch = channel.fromPath(params.annotation_bed, checkIfExists: true)
        output_ch = channel.fromPath(params.output_dir)
        get_stand_ch = channel.fromPath(params.getStrand)
        clean_counts_ch = channel.fromPath(params.cleanCount)
        multiqc_config_ch = channel.fromPath(params.multiqc_config)

        if (params.batch_info){
        setup(params.run1, params.run2, params.dest)
        }
        rnaSeq(index_ch,
                annotation_ch,
                reference_ch,
                bed_ch,
                get_stand_ch,
                clean_counts_ch,
        )
}

workflow.onComplete {

        def msg = """\
        Pipeline execution summary
        ---------------------------
        Completed at: ${workflow.complete}
        Duration    : ${workflow.duration}
        workDir     : ${workflow.workDir}
        exit status : ${workflow.exitStatus}
        """
        .stripIndent()
	
        println ""
	println "Execution status: ${workflow.success ? msg : 'failed'}"
	

}
workflow.onError {
	def error_msg = """\
        Pipeline error info
        ---------------------------
        Error Message : ${workflow.errorMessage}
        exit status   : ${workflow.exitStatus}
        """
        .stripIndent()
	
	println "Error: Pipeline execution stopped with the following message: ${error_msg}"
}




