import gzip
import os
from optparse import OptionParser


'''
takes vcf and ped as input, seperate the vcf by trios, exclude varaints are all missing the the trio
'''
# Basic Input Files, required   
#example:    python adhoc.1.VcfTotrio.py -v PCGC_target3_0223.vcf -p CHD_MedExomeKit.ped
parser = OptionParser()
parser.add_option("-v", "--vcf", dest="VCFfile",help="input VCF file", metavar="VCFfile")
parser.add_option("-p", "--ped", dest="PEDfile",help="input PED file", metavar="PEDfile")

(options, args) = parser.parse_args()
vcf_name = options.VCFfile
ped_name = options.PEDfile

# make vcf trio dir
trio_dir = os.path.dirname(vcf_name)
trio_dir_name = trio_dir+'vcf_trio/'
if not os.path.exists(trio_dir_name):
    os.makedirs(trio_dir_name)

with open(vcf_name, 'r') as f:
    for line in f: 
        if line[:6]=='#CHROM': 
            samples = line.split()
            break

# ulimit -n 2048 
sample_index={}
with open(ped_name) as f:
    for line in f:
        family, proband,father,mother = line.split()[:4]
        if proband in samples and father in samples and mother in samples:
            sample_index[proband]=[father,mother,samples.index(proband),samples.index(father),samples.index(mother)]
        else:
            print line

#print sample_index
print len(sample_index)

with open(vcf_name, 'r') as f:
    head = []
    for line in f: 
        if line[0]=='#': # get and write head
            if line[1]=='#':
                # format and info line
                head.append(line)
            else: #
                all_samples = line.split()
                head_f = all_samples[:9] # CHROM ... FORMAT
  	 
                f = [open(trio_dir_name+ '_'.join([proband, sample_index[proband][0], sample_index[proband][1] ]) + '.vcf', "w") for proband in sample_index]
                n = len(f)
                for i in range(n):
                    proband = f[i].name.split('/')[-1].split('_')[0]
                    proband_index, father_index, mother_index = sample_index[proband][-3:]
                    trio = [all_samples[proband_index],all_samples[father_index],all_samples[mother_index]]
                    f[i].write(''.join(head))
                    f[i].write('\t'.join(head_f + trio)+'\n')
        
        
        else: 
            data = line.split()
            INFOstring = data[7]
            for i in range(n):
                proband = f[i].name.split('/')[-1].split('_')[0]
                proband_index, father_index, mother_index = sample_index[proband][-3:]
                trio = [data[proband_index],data[father_index],data[mother_index]]
                trio_GT = [data[proband_index].split(':')[0],data[father_index].split(':')[0],data[mother_index].split(':')[0]]
                if trio_GT != ['./.','./.','./.'] and trio_GT != ['0/0','0/0','0/0'] :
                    f[i].write("\t".join(data[:9]+trio)+'\n')

for fh in f:
    fh.close()

print 'finished'
