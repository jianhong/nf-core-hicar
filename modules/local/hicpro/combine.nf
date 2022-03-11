process HICPRO_COMBINE {
    tag "$meta.id"
    label 'process_medium'

    conda (params.enable_conda ? "conda-forge::biopython=1.70" : null)
    container "${ workflow.containerEngine == 'singularity' &&
                    !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/biopython:1.70--np112py36_1' :
        'quay.io/biocontainers/biopython:1.70--np112py36_1' }"

    input:
    tuple val(meta), path(bams)
    path merge_sam_path
    val hicpro_version

    output:
    tuple val(meta), path("${prefix}_bwt2paris.bam"), emit: bam
    path "versions.yml"                             , emit: versions

    script:
    def args   = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    python $merge_sam_path \\
        $args \\
        -f ${bams[0]} \\
        -r ${bams[1]} \\
        -o ${prefix}_bwt2paris.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        HiC-Pro: $hicpro_version
    END_VERSIONS
    """
}
