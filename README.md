Guide - Metabarcoding analysis

System – NK Macbook Air
1.	Lauch Docker Desktop
2.	Open terminal app
3.	Activate environment: conda activate epi2me_nk
4.	Navigate to project directory in: cd /Users/nkylilis/Desktop/metabarcoding
5. 	Make a named experiment folder in metabarcoding folder and download repository microbial-metabarcoding from Tsaltas lab on github
6.	Create data/fastq folders and move sequencing files to to fastq folder (make separate experiments for 16S & ITS samples)
7. 	Make sample_sheet.csv in data/fastq
8. 	Run: bash 0_make_scripts_executable.sh
9. 	For 16S run: bash 00_run_all.sh 16S 
10. 	For ITS run: bash 00_run_all.sh ITS 
