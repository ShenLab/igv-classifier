#!/bin/bash
#$ -cwd -l mem=10G,time=6:: -N GenBQSR

# This script takes a bam file and generates the base quality score recalibration table using GATK
# If the script is passed a list of bam files a single recalibration table is made covering all 24 chromosomes, this is then passed to the next script which is called as an array to apply the recalibration on each bam separately
#    InpFil - (required) - Path to Bam file
#    RefFil - (required) - shell file containing variables with locations of reference files, jar files, and resource directories; see list below for required variables
#    TgtBed - (required) - Exome capture kit targets bed file (must end .bed for GATK compatability) ; may be specified using a code corresponding to a variable in the RefFil giving the path to the target file
#    LogFil - (optional) - File for logging progress
#    Flag - A - AllowMisencoded - see GATK manual, causes GATK to ignore abnormally high quality scores that would otherwise indicate that the quality score encoding was incorrect
#    Flag - P - PipeLine - call the next step in the pipeline at the end of the job
#    Flag - B - BadET - prevent GATK from phoning home
#    Help - H - (flag) - get usage information

#list of required vairables in reference file:
# $REF - reference genome in fasta format - must have been indexed using 'bwa index ref.fa'
# $INDEL - Gold standard INDEL reference from GATK
# $INDEL1KG - INDEL reference from 1000 genomes
# $DBSNP - dbSNP vcf from GATK
# $EXOMPPLN - directory containing exome analysis pipeline scripts
# $GATK - GATK jar file 
# $ETKEY - GATK key file for switching off the phone home feature, only needed if using the B flag

#list of required tools:
# java <http://www.oracle.com/technetwork/java/javase/overview/index.html>
# GATK <https://www.broadinstitute.org/gatk/> <https://www.broadinstitute.org/gatk/download>

## This file also requires exome.lib.sh - which contains various functions used throughout the Exome analysis scripts; this file should be in the same directory as this script

###############################################################

#set default arguments
usage="
ExmAln.5.GenerateBQSRTable.sh -i <InputFile> -r <reference_file> -t <targetfile> -l <logfile> -PABH

     -i (required) - Path to Bam file
     -r (required) - shell file containing variables with locations of reference files and resource directories
     -t (required) - Exome capture kit targets or other genomic intervals bed file (must end .bed for GATK compatability)
     -l (optional) - Log file
     -P (flag) - Call next step of exome analysis pipeline after completion of script
     -A (flag) - AllowMisencoded - see GATK manual
     -B (flag) - Prevent GATK from phoning home
     -H (flag) - echo this message and exit
"

AllowMisencoded="false"
PipeLine="false"
BadET="false"

#get arguments
while getopts i:r:a:t:l:PABH opt; do
    case "$opt" in
        i) InpFil="$OPTARG";;
        r) RefFil="$OPTARG";; 
        a) ArrNum="$OPTARG";; 
        t) TgtBed="$OPTARG";; 
        l) LogFil="$OPTARG";;
        P) PipeLine="true";;
        A) AllowMisencoded="true";;
        B) BadET="true";;
        H) echo "$usage"; exit;;
    esac
done

#check all required paramaters present
if [[ ! -e "$InpFil" ]] || [[ ! -e "$RefFil" ]] || [[ -z "$TgtBed" ]]; then echo "Missing/Incorrect required arguments"; echo "$usage"; exit; fi

#Call the RefFil to load variables
RefFil=`readlink -f $RefFil`
source $RefFil

#Load script library
source $EXOMPPLN/exome.lib.sh #library functions begin "func" #library functions begin "func"

InpFil=`readlink -f $InpFil` #resolve absolute path to bam
BamFil=$(tail -n+$ArrNum $InpFil | head -n 1) 
BamNam=`basename $BamFil | sed s/.bam//` #a name to use for the various files
if [[ -z "$LogFil" ]];then LogFil=$BamNam.GenBQSR.log; fi # a name for the log file
RclTable=$BamNam.recal.table # output - base quality score recalibration table
GatkLog=$BamNam.gatklog #a log for GATK to output to, this is then trimmed and added to the script log
TmpLog=$BamNam.GenBQSR.temp.log #temporary log file 
TmpDir=$BamNam.GenBQSR.tempdir; mkdir -p $TmpDir #temporary directory

#Start Log
ProcessName="Generate Base Quality Score Recalibration Table with GATK" # Description of the script - used in log
funcWriteStartLog

#Generate target file
StepName="Create recalibration data file using GATK BaseRecalibrator" # Description of this step - used in log
StepCmd="java -Xmx7G -Djava.io.tmpdir=$TmpDir -jar $GATKJAR
 -T BaseRecalibrator 
 -R $REF 
 -I $BamFil 
 -L $TgtBed 
 -ip 50
 -knownSites $DBSNP 
 -knownSites $INDEL 
 -knownSites $INDEL1KG 
 -o $RclTable 
 --filter_mismatching_base_and_quals
 -log $GatkLog" #command to be run
funcGatkAddArguments # Adds additional parameters to the GATK command depending on flags (e.g. -B or -F)
funcRunStep



BamNam=`basename $BamFil | sed s/.bam//` #a name to use for the various files
if [[ -z "$LogFil" ]];then LogFil=$BamNam.appBQSR.log; fi # a name for the log file
RclFil=$BamNam.recalibrated.bam #file to output recalibrated bam to
FlgStat=${RclFil/bam/flagstat} # file to output samtools flagstats on the final file to
GatkLog=$BamNam.AppBQSR.gatklog #a log for GATK to output to, this is then trimmed and added to the script log
TmpLog=$BamNam.AppBQSR.temp.log #temporary log file
TmpDir=$BamNam.AppBQSR.tempdir; mkdir -p $TmpDir #temporary directory
TmpTar=TmpTarFil.$Chr.bed #temporary target file

#Start Log
ProcessName="Recalibrate Base Quality Scores with GATK" # Description of the script - used in log
funcWriteStartLog

#Apply Recalibration
StepName="Apply recalibration using GATK PrintReads" # Description of this step - used in log
StepCmd="java -Xmx7G -Djava.io.tmpdir=$TmpDir -jar $GATKJAR
 -T PrintReads 
 -R $REF 
 -I $BamFil 
 -BQSR $RclTab
 -L $TgtBed
 -ip 50
 -o $RclFil 
 --emit_original_quals 
 --filter_mismatching_base_and_quals
 -log $GatkLog" #command to be run
funcGatkAddArguments # Adds additional parameters to the GATK command depending on flags (e.g. -B or -F)
funcRunStep

InpNam=`$RclFil  | sed s/.bam//`
BamFil=`readlink -f $RclFil` #resolve absolute path to bam
BamNam=`basename $BamFil | sed s/.bam//` #a name to use for the various files
if [[ -z "$LogFil" ]];then LogFil=$BamNam.appBQSR.log; fi # a name for the log file
RclFil=$BamNam.recalibrated.bam #file to output recalibrated bam to
FlgStat=${RclFil/bam/flagstat} # file to output samtools flagstats on the final file to
GatkLog=$BamNam.AppBQSR.gatklog #a log for GATK to output to, this is then trimmed and added to the script log
TmpLog=$BamNam.AppBQSR.temp.log #temporary log file
TmpDir=$BamNam.AppBQSR.tempdir; mkdir -p $TmpDir #temporary directory
TmpTar=TmpTarFil.$Chr.bed #temporary target file

#Start Log
ProcessName="Recalibrate Base Quality Scores with GATK" # Description of the script - used in log
funcWriteStartLog

#Apply Recalibration
StepName="Apply recalibration using GATK PrintReads" # Description of this step - used in log
StepCmd="java -Xmx7G -Djava.io.tmpdir=$TmpDir -jar $GATKJAR
 -T PrintReads 
 -R $REF 
 -I $BamFil 
 -BQSR $RclTab
 -L $TgtBed
 -ip 50
 -o $RclFil 
 --emit_original_quals 
 --filter_mismatching_base_and_quals
 -log $GatkLog" #command to be run
funcGatkAddArguments # Adds additional parameters to the GATK command depending on flags (e.g. -B or -F)
funcRunStep

#Get flagstat
StepName="Output flag stats using Samtools"
StepCmd="samtools flagstat $RclFil > $FlgStat"
funcRunStep


#End Log
funcWriteEndLog

#Clean up
#if [[ -e $RclFil ]] && [[ "$KillFile" == "true" ]]; then rm $BamFil ${BamFil/bam/bai}; fi
