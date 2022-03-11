/*
 * HiC-pro - Detect valid interaction from aligned mates
 */

include { HICPRO_VALID_FRAGMENT       } from '../../modules/local/hicpro/valid_fragment'
include { HICPRO_VALID_DNASE          } from '../../modules/local/hicpro/valid_dnase'

workflow PREPARE_GENOME {
    take:
    reads             // channel: tuple val(meta), path(reads)
    fragment          // channel: path fragment
    dnase             // channel: value dnase
    hicpro_version    // value hicpro version
    map_fragment_ptah // channel: path mapped_2hic_fragments.py
    map_dnase_path    // channel: path mapped_2hic_dnase.py

    main:
    /*
     * Detect valid interaction from aligned mates
     */
    if(dnase){
        ch_version = HICPRO_VALID_DNASE(HICPRO_COMBINE.out.bam, map_dnase_path, hicpro_version).versions
    }else{
        ch_version = HICPRO_VALID_FRAGMENT(HICPRO_COMBINE.out.bam, fragment, map_fragment_ptah, hicpro_version).versions
    }

    emit:
    bam               = HICPRO_COMBINE                // tuple val(meta), path(bam)
    versions          = ch_version                    // path: *.version.yml
}
