#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// run test: PROFILE=conda nextflow run tests/workflow/calldistalpeak/ -entry test_call_frag_peak -c tests/config/nextflow.config
// Don't overwrite global params.modules, create a copy instead and use that within the main script.
def modules = params.modules.clone()
def getSubWorkFlowParam(modules, mods) {
    def Map options = [:]
    mods.each{
        val ->
        options[val] = modules[val]?:[:]
    }
    return options
}

include { GUNZIP
    } from '../../../modules/nf-core/modules/gunzip/main' addParams(
        options: [publish_files:'']   )
include { CHROMSIZES
    } from '../../../modules/local/genome/chromsizes' addParams(
        options: [publish_files:'']   )
include { R1_PEAK
    } from '../../../subworkflows/local/calldistalpeak' addParams(
        options: getSubWorkFlowParam(modules, [
            'merge_r1reads', 'r1reads', 'macs2_callr1peak',
            'dump_r1_reads_per_group', 'dump_r1_reads_per_sample',
            'merge_r1peak', 'r1qc', 'bedtools_genomecov_per_group',
            'bedtools_genomecov_per_sample', 'bedtools_sort_per_group',
            'bedtools_sort_per_sample', 'ucsc_bedclip',
            'ucsc_bedgraphtobigwig_per_r1_group',
            'ucsc_bedgraphtobigwig_per_r1_sample']))

process CREATE_PAIRS {
    input:
    path chromsizes
    path gtf

    output:
    path "test.pairs.gz", emit: pairs

    script:
    """
    #!/usr/bin/env Rscript
    options(scipen=10)
    chromsize <- read.delim("$chromsizes", header=FALSE)
    chromosomes <- chromsize[, 1]
    seqlengths <- chromsize[, 2]
    names(seqlengths) <- chromosomes
    gtf <- read.delim("$gtf", header=FALSE)
    evts <- unique(gtf[gtf[, 3]=="start_codon", c(1, 4, 7)])
    evts <- evts[evts[, 2]<seqlengths[evts[, 1]], ] ## keep the events within seqlen
    stopifnot(length(evts)>2)
    set.seed(123)
    generatePairs <- function(chromsize, N=1e6){
        # create table with columns: readID chrom1 pos1 chrom2 pos2 strand1 strand2 pair_type
        readID <- paste0("r", formatC(seq.int(N), width=nchar(as.character(N)), flag="0"))
        events1 <- sample(seq.int(nrow(evts)), N, replace=TRUE)
        events2 <- sample(events1, N, replace=TRUE)
        distance1 <- sample(seq.int(2000), N, replace=TRUE) - 28000 ## from 26K to 30K
        distance2 <- sample(seq.int(1200), N, replace=TRUE)-600 ## promoter region
        chrom1 <- evts[events1, 1]
        pos1 <- evts[events1, 2] + distance1
        strand1 <- evts[events1, 3]
        chrom2 <- evts[events2, 1]
        pos2 <- evts[events2, 2] + distance2
        strand2 <- ifelse(strand1=="-", "+", "-")
        paste(readID, chrom1, pos1, chrom2, pos2, strand1, strand2, "UU", sep="\\t")
    }
    header <- c("## pairs format v1.0.0",
                "#shape: whole matrix",
                "#genome_assembly: unknown",
                paste("#chromsize:", chromsize[, 1], chromsize[, 2]),
                "#columns: readID chrom1 pos1 chrom2 pos2 strand1 strand2 pair_type")
    content <- generatePairs(chromsize)
    gz <- gzfile("test.pairs.gz", "w")
    writeLines(c(header, content), gz)
    close(gz)
    """
}

process CHECK_PEAKS {
    publishDir "${params.outdir}",
        mode: "copy"
    input:
    path peak
    path gtf

    output:
    path "results.txt", emit: qc

    script:
    """
    #!/usr/bin/env Rscript
    peaks <- read.delim("$peak", header=FALSE)
    total <- nrow(peaks)
    gtf <- read.delim("$gtf", header=FALSE)
    evts <- unique(gtf[gtf[, 3]=="start_codon", c(1, 4)])
    nearestDist <- function(p, events_start){
        p <- rowMeans(p)
        p <- sort(p)
        e <- sort(events_start)
        dist <- sapply(p, function(.ele) min(abs(.ele-e)))
        sum(abs(dist)<30000, na.rm=TRUE)
    }
    peaks <- split(peaks[, -1], peaks[, 1])
    evts <- split(evts[, 2], evts[, 1])
    cnt <- mapply(nearestDist, peaks, evts[names(peaks)])
    pct <- sum(cnt)/total
    stopifnot(pct>.99)
    writeLines(ifelse(pct>0.99, "YES", "NO"), "results.txt")
    """
}

workflow test_call_frag_peak {
    fasta           = GUNZIP([[id:"test"],file(params.test_data.fasta, checkIfExists: true)]).gunzip.map{it[1]}
    chromsizes      = CHROMSIZES ( fasta ).sizes
    macs_gsize      = params.test_data.macs_gsize
    gtf             = file(params.test_data.gtf, checkIfExists: true)
    validpair       = CREATE_PAIRS(chromsizes, gtf).pairs.map{[[id:'test', group:'gp1'], it]}

    R1_PEAK ( validpair, chromsizes, macs_gsize, gtf )
    CHECK_PEAKS (R1_PEAK.out.mergedpeak, gtf)
}
