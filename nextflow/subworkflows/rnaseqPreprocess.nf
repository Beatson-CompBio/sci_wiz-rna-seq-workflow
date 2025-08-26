// import the processes from the module file
include { MAPPING } from '../modules/mapping'
include { COUNT; IDENTIFY_STRAND } from '../modules/count'
include { BAM_TO_CRAM } from '../modules/bam_to_cram'
include { MULTIQC } from '../modules/multiqc'
include { FASTP } from '../modules/fastp'
//import sub modules
include { rawQc } from '../subworkflows/qualityCheck'

workflow rnaSeq {
    take:
        index_ch
        annotation_ch
        reference_ch
        bed_ch
        get_stand_ch
        clean_counts_ch

    main:
        read_ch = rawQc().read_ch
        MAPPING(read_ch , index_ch)
        // Determine the strand of the read 
        IDENTIFY_STRAND(bed_ch, MAPPING.out.sorted_bam_file, get_stand_ch)
        COUNT(MAPPING.out.sorted_bam_file.collect(), annotation_ch, IDENTIFY_STRAND.out.strand, clean_counts_ch)
        fastp_ch = rawQc.out.fastp_json
        fastqc_ch = rawQc.out.fastqc_logs
        fastqscreen_ch = rawQc.out.fastqscreen_logs
        MULTIQC(fastp_ch.mix(fastqc_ch, fastqscreen_ch, MAPPING.out, COUNT.out.log).collect(), params.multiqc_config)
        // convert bam to crams
        sampleId_ch = rawQc.out.read_ch.map{ row -> row[0] }
        BAM_TO_CRAM(sampleId_ch, MAPPING.out.sorted_bam_file, reference_ch)
}
