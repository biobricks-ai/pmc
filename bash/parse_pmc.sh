#!/usr/bin/env bash

##Set-up env on linux/ubuntu
if aws --version; then
	    echo "Command succeeded: awscli installed"
    else
	      sudo apt install unzip;
	        wget "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -O "awscliv2.zip";
		  unzip -o awscliv2.zip;
		    sudo ./aws/install;
		      sudo apt-get update;
		        sudo apt-get install awscli;
fi

if R --version; then
	  echo "Command succeeded: R installed"
  else
	    sudo apt install r-base-core
fi

if dvc --version; then
	  echo "Command succeeded: dvc installed"
  else
	    sudo apt update;
	      sudo apt install snapd;
	        sudo snap install dvc --classic;
fi

## Download documentation info for pmc data files:
mkdir -p download/output_documentation;
wget -r -nd -m -P ./download/output_documentation -A "*.csv" ftp://ftp.ncbi.nlm.nih.gov/pub/pmc/oa_bulk/oa_comm/txt/

## AWS buckets: aws s3 ls s3://pmc-oa-opendata/oa_comm/txt/all/ --no-sign-request
echo "Include user external download location: ex. /path/to/download/";
read user_path;
DIR='output_pmc_txt';
output_path=$user_path$DIR;
mkdir -p $output_path
if [ "$(ls -A $output_path)" ]; then
	   echo "$output_path is not Empty"
   else
	     aws s3 sync s3://pmc-oa-opendata/oa_comm/txt/all/ $output_path --no-sign-request;
fi

mkdir -p $output_path/pmc_front $output_path/pmc_body;
if [[ "$(ls -A $output_path/pmc_front)" && "$(ls -A $output_path/pmc_body)" ]]; then
	  echo "$output_path/pmc_body and $output_path/pmc_front are not Empty"
  else
	    ## Split each text file into paper sections front and body: Reduces file size
	      for inputFile in $output_path/*.txt; do
		          csplit -ks -f $output_path/`basename $inputFile`_split $inputFile /==/ {2};
			      rm $inputFile;
			        done
				  ## Move sections of pmc data to proper directory
				    for i in $output_path/*split00*; do
					        rm $i
						  done
						    for i in $output_path/*split03*; do
							        rm $i
								  done
								    for i in $output_path/*split01*; do
									        mv $i $output_path/pmc_front;
										  done
										    for i in $output_path/*split02*; do
											        mv $i $output_path/pmc_body;
												  done
fi

## Generate list file:
for i in $output_path/pmc_body/*; do
	  echo $i;
  done > download/tmp_pmc_body
  for i in $output_path/pmc_front/*; do
	    echo $i;
    done > download/tmp_pmc_front

