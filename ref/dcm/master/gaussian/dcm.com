%nproc=4
%mem=5760MB
%chk=dcm.chk
#P PBE1PBE/aug-cc-pvdz scf(maxcycle=200) opt Freq=NoRaman

DCM		

0 1
C          5.48910        2.24640        0.00000
H          5.84580        1.23760        0.00000
H          5.84580        2.75080       -0.87370
Cl         6.07580        3.07600        1.43700
Cl         3.72910        2.24640        0.00000

