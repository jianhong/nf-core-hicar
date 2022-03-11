process HICPRO_VALID_FRAGMENT {
    tag "$meta.id"
    label 'process_medium'

    conda (params.enable_conda ? "conda-forge::biopython=1.70" : null)
    container "${ workflow.containerEngine == 'singularity' &&
                    !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/biopython:1.70--np112py36_1' :
        'quay.io/biocontainers/biopython:1.70--np112py36_1' }"

    input:
    tuple val(meta), path(bam)
    path fragment
    path map_fragment_ptah
    val hicpro_version

    output:
    tuple val(meta), path("${prefix}.validPairs")   , emit: validpair
    tuple val(meta), path("${prefix}.DEPairs")      , emit: de_pair
    tuple val(meta), path("${prefix}.SCPairs")      , emit: sc_pair
    tuple val(meta), path("${prefix}.REPairs")      , emit: re_pair
    tuple val(meta), path("${prefix}.FiltPairs")    , emit: filt_pair
    tuple val(meta), path("${prefix}.RSstat")       , emit: stats
    path "versions.yml"                             , emit: versions

    script:
    def args   = task.ext.args ?: ''
    prefix = bam.toString() - ~/.bam/
    """
    python $map_fragment_ptah \\
        $args \\
        -f $fragment \\
        -r ${bam}

    sort -k2,2V -k3,3n -k5,5V -k6,6n \\
        -o ${prefix}.validPairs \\
        ${prefix}.validPairs

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        HiC-Pro: $hicpro_version
    END_VERSIONS
    """
}
