include { FASTP } from '../modules/fastp'
include { FASTQC } from '../modules/fastqc'
include { MULTIQC } from '../modules/multiqc'
include { FASTQSCREEN } from '../modules/fastqscreen'

//Workflow to run QC on raw fastq files, including trimming, FastQC, and optional FastQ Screen

workflow rawQc {
    read_ch = channel.fromFilePairs(params.reads, checkIFExists: true)
            | map { row -> 
            Transformer.transformSampleId(row)
    }

    // Broadcast one database folder to all FASTQSCREEN tasks
    db_ch = Channel.fromPath(params.fastqscreen_db_dir, checkIfExists: true)

    main:
        fastp_json = null
        fastp_html = null
        if (!params.initial_qc) {
            FASTP(read_ch)
            read_ch = FASTP.out.trim_reads
            fastp_json = FASTP.out.json
            fastp_html = FASTP.out.html
        }
        FASTQC(read_ch)
        FASTQSCREEN(read_ch,db_ch)
        
        if (params.initial_qc){
            qc_ch = FASTQC.out.logs_QC.concat(FASTQSCREEN.out.logs_FQS)
            MULTIQC(qc_ch.collect(), params.multiqc_config)
        }

    emit:
        read_ch
        fastp_json
        fastp_html
        fastqc_logs = FASTQC.out.logs_QC
        fastqscreen_logs = FASTQSCREEN.out.logs_FQS
}
