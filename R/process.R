library(purrr)
library(utils)
library(tools)
library(vroom)
library(arrow)
library(tibble)
library(data.table)
library(dplyr)
library(readr)
library(here)
library(stringr)
library(fs)
library(arsenal)    
library(tidyr)

##----------------- User Input location to download intermediate files
if (interactive()) {
	  print("Format Example:Folder/to/File/")
  externalDriveLocation <- readline("Temporary File Storage Location:")
} else {
	  cat("Temporary File Storage Location:")
  externalDriveLocation <- readLines("stdin", n = 1)
}

joinPath<-function(x)file.path(externalDriveLocation,x)

data_dir <- "data"
download_dir <- "download"
download_doc <-file.path(download_dir,"output_documentation")
download_txt <-file.path(externalDriveLocation,"output_pmc_txt")
download_body <-file.path(externalDriveLocation,"output_pmc_txt/pmc_body")
download_front <-file.path(externalDriveLocation,"output_pmc_txt/pmc_front")

base_name <- function(filename) {
	  file_path_sans_ext(basename(filename))
}
mkdir = function (dir) {
	  if (!dir.exists(dir)) {
		      dir.create(dir,recursive=TRUE)
  } 
}
map(c(data_dir,download_doc,download_txt,download_body,download_front),mkdir)


##----------------- Process csv documentation folders
process_documentation_files<-function(filename){
	  list.files(download_doc, full.names = TRUE, pattern = 'csv')|>
    map(function(filename) {
		      df <- vroom::vroom(filename,',')
		            arrow::write_parquet(df,file.path(data_dir,paste0(base_name(filename),".parquet")))
		          })
}
combineParquetDf<-function(parquet_tmp_list){
	  tmpDf<-data.table::rbindlist(lapply(Sys.glob(parquet_tmp_list), arrow::read_parquet), fill = TRUE)
  arrow::write_parquet(tmpDf, file.path(data_dir,paste0("pmc_data_documentation.parquet")))
    rm(tmpDf)
    map(parquet_tmp_list,file.remove)
}

process_documentation_files()
tmp_files=list.files(data_dir, pattern = '^oa', full.names = TRUE)
combineParquetDf(tmp_files)

##----------------- Process pmc text data files
split_list<-function(input_file){
	  file_list=read.csv(input_file, header = FALSE)
  listCount=length(file_list$V1)/5000
    splitFileJoinList=split(file_list, rep(1:listCount))
    return(splitFileJoinList)
}

parse_txt_data<-function(input_file){
	  parsed_file=read_file(input_file)
  output_tibble=tibble(parsed_file) |> mutate(fileid=base_name(input_file)) |> 
      mutate(parsed_front_data=reduce2(c("==== Front","==== Body"), c('',''),  .init = parsed_file, str_replace)) |>
      select(parsed_front_data, fileid)
        return(output_tibble)
}

combine_txt_data<-function(input_file_list, outputFileName){
	  output_data=list()
  for( i in seq(1,length(input_file_list$V1))){
	      output_data[[i]]=parse_txt_data(input_file_list$V1[i])
    }
    combined_tibble = do.call(rbind, output_data)
    arrow::write_parquet(combined_tibble, outputFileName)
      rm(combined_tibble)
}
combine_list_data<-function(all_data_lists, type_data){
	  for(i in seq(1,length(all_data_lists))){
		      combine_txt_data(all_data_lists[[i]], file.path(data_dir, paste0("PMC_data_shard_",type_data,"_",i,".parquet")))
  }  
}

list_split_body=split_list(file.path(download_dir,'tmp_pmc_body'))
list_split_front=split_list(file.path(download_dir,'tmp_pmc_front'))

combine_list_data(list_split_body, "body")
combine_list_data(list_split_front, "front")


