"""
Convert PacBio BAX files to BAM files.


Required modules (or later version):

module load miniconda/4.5.11
module load pbconda/201809
"""

import pandas as pd

import collections
import os

localrules: bax2bam_merge_md5, bax2bam_merge_fofn, bax2bam_size_record


# Bash "strict mode"
shell.prefix('set -euo pipefail; ')


#############
### Rules ###
#############

# bax2bam_all_files
#
# Finalize files and set permissions. Separate this rule from dynamic rules (confuses snakemake to mix other files
# in dynamic rules) and guarantee that the quality control files (.md5 and .size) are present with the FOFN.
rule bax2bam_all_files:
    input:
        fofn='temp/pacbio.fofn',
        md5='pacbio.fofn.md5',
        sz='pacbio.fofn.size'
    output:
        fofn='pacbio.fofn'
    shell:
        """cp {input.fofn} {output.fofn}; """
        """chmod 444 {output.fofn}; """
        """chmod 555 files"""

# bax2bam_merge_fofn
#
# Merge BAM FOFN files. Write to temp.
rule bax2bam_merge_fofn:
    input:
        bam=dynamic('files/{cell}.subreads.bam')
    output:
        fofn=temp('temp/pacbio.fofn')
    run:

        with open(output.fofn, 'w') as out_file:
            for bam_file_name in input.bam:
                out_file.write(os.path.abspath(bam_file_name))
                out_file.write('\n')

        shell("""chmod 444 {output.fofn}""")


# bax2bam_size_record
#
# Make size records for each BAM.
rule bax2bam_size_record:
    input:
        bam=dynamic('files/{cell}.subreads.bam')
    output:
        sz='pacbio.fofn.size'
    run:

        # Get size records
        size_record_list = list()

        for bam_file in input.bam:
            size_record_list.append(pd.Series(
                [os.stat(bam_file).st_size, os.path.abspath(bam_file)],
                index=['SIZE', 'FILE']
            ))

        # Merge and write
        pd.concat(
            size_record_list, axis=1
        ).T.to_csv(
            output.sz, sep='\t', index=False
        )

        shell("""chmod 444 {output.sz}""")

# bax2bam_merge_md5
#
# Merge MD5 records for each cell BAM.
rule bax2bam_merge_md5:
    input:
        md5=dynamic('temp/md5/{cell}.md5')
    output:
        md5='pacbio.fofn.md5'
    run:

        with open(output.md5, 'w') as out_file:
            for file_name in input.md5:
                with open(file_name, 'r') as in_file:
                    for line in in_file:
                        line = line.strip()

                        if not line:
                            continue

                        out_file.write(line)
                        out_file.write('\n')

        shell("""chmod 444 {output.md5}""")

# bax2bam_md5_record
#
# Make MD5 checksum of the BAM
rule bax2bam_md5_record:
    input:
        bam='files/{cell}.subreads.bam'
    output:
        md5='temp/md5/{cell}.md5'
    shell:
        """md5sum $(readlink -f {input.bam}) > {output.md5}; """
        """chmod 444 {output.md5}"""

# bax2bam_to_bam
#
# Make BAM
rule bax2bam_to_bam:
    input:
        fofn='temp/cells/{cell}.fofn'
    output:
        bam='files/{cell}.subreads.bam',
        pbi='files/{cell}.subreads.bam.pbi'
    shell:
        """bax2bam -f {input.fofn} -o files/{wildcards.cell}; """
        """rm files/{wildcards.cell}.scraps*; """
        """chmod 444 {output.bam} {output.pbi}"""

# bax2bam_fofn_by_cell
#
# Get one FOFN for each cell in the input FOFN, which contains BAX files for all cells. Each output FOFN will have
# 3 lines (3 BAX files per cell).
rule bax2bam_fofn_by_cell:
    input:
        fofn=config['fofn']
    output:
        fofn=dynamic('temp/cells/{cell}.fofn')
    run:

        # Initialize cell dictionary (key: Cell, value: List of FOFN files)
        cell_dict = collections.defaultdict(list)

        # Save cells to cell_dict
        with open(input.fofn, 'r') as in_file:
            for line in in_file:

                line = line.strip()

                if not line:
                    continue

                if not line.endswith('.bax.h5'):
                    raise RuntimeError('Found non-BAX (.bax.h5) file in input FOFN: {}'.format(line))

                cell_dict[os.path.basename(line).split('.')[0]].append(line)

        # Check cells
        for cell in cell_dict.keys():
            cell_fofn = cell_dict[cell]

            if len(cell_fofn) != 3:
                raise RuntimeError('Expected 3 BAX files for cell "{}": Found {}'.format(cell, len(cell_fofn)))

            for bax_file in cell_fofn:
                if not os.path.isfile(bax_file):
                    raise RuntimeError('FOFN contains a path to a missing BAX file: {}'.format(bax_file))

        # Write FOFN files
        for cell in cell_dict.keys():
            with open('temp/cells/{}.fofn'.format(cell), 'w') as out_file:
                out_file.write('\n'.join(sorted(cell_dict[cell])))
