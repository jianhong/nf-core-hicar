/*
 * HiC-pro - Two-steps Reads Mapping
 */

include {
    BOWTIE2_ALIGN as BOWTIE2_END2END;
    BOWTIE2_ALIGN as BOWTIE2_TRIMMED  } from '../../modules/nf-core/modules/bowtie2/align/main'
include { SAMTOOLS_MERGE              } from '../../modules/nf-core/modules/samtools/merge/main'
include {
    SAMTOOLS_SORT as SAMTOOLS_SORT_4MERGE } from '../../modules/nf-core/modules/samtools/sort/main'
include {
    SAMTOOLS_VIEW as SAMTOOLS_FILTER  } from '../../modules/nf-core/modules/samtools/view/main'
include { HICPRO_TRIM                 } from '../../modules/local/hicpro/trim'
include { HICPRO_COMBINE              } from '../../modules/local/hicpro/combine'

workflow PREPARE_GENOME {
    take:
    reads             // channel: tuple val(meta), path(reads)
    index             // channel: path  index
    enzyme            // channel: value enzyme
    ligation_site     // channel: value ligation_site
    dnase             // channel: value dnase
    hicpro_version    // value hicpro version
    cutsite_trimming  // channel: path cutsite_trimming
    merge_sam_path    // channel: path mergeSAM.py

    main:

    /*
     * Map reads end to end
     */
    ch_version = BOWTIE2_END2END(reads, index, true).versions
    if(!dnase){
        SAMTOOLS_FILTER(BOWTIE2_END2END.out.bam)
        ch_version = ch_version.mix(SAMTOOLS_FILTER.out.versions)

        /*
         * trim the unmapped reads
         */
        HICPRO_TRIM(BOWTIE2_END2END.out.fastq, cutsite_trimming, ligation_site, hicpro_version)
        ch_version = ch_version.mix(HICPRO_TRIM.out.versions)

        /*
         * Map the unmapped reads
         */
        BOWTIE2_TRIMMED(HICPRO_TRIM.out.reads, index, false)

        /*
         * Merge the mapped reads
         */
        ch_merge = SAMTOOLS_FILTER.out.bam.join(BOWTIE2_TRIMMED.out.bam)
        SAMTOOLS_MERGE(ch_merge)
        SAMTOOLS_SORT_4MERGE(SAMTOOLS_MERGE.out.bam)
        ch_version = ch_version.mix(SAMTOOLS_MERGE.out.versions)
        ch_merged = SAMTOOLS_SORT.out.bam
    }else{
        ch_merged = BOWTIE2_END2END.out.bam
    }


    /*
     * Combine the mates
     */
     HICPRO_COMBINE(ch_merged, merge_sam_path, hicpro_version)
     ch_version = ch_version.mix(HICPRO_COMBINE.out.versions)

    emit:
    bam               = HICPRO_COMBINE.out.bam        // tuple val(meta), path(bam)
    versions          = ch_version                    // path: *.version.yml
}
