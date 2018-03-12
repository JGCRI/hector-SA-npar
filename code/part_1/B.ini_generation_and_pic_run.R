# this script creates ini file using each combination of parameters, then runs the hector, then 
# extracts desired output and write into output file. 

# -----------------------------------------------------------------------------
# 0. set up some basics
library( 'tidyr' )

# Decide which rcp scenario to run
rcpXX <- "rcp26"

# -----------------------------------------------------------------------------
# 0.5 Settings you will definitely need to overwrite in your code
pic_hectorSA_path <- '/pic/projects/GCAM/Dorheim/CMS/hector-SA-npar'
setwd( pic_hectorSA_path )
pic_hector_path <- '/pic/projects/GCAM/Dorheim/CMS/hector'

# -----------------------------------------------------------------------------
# 1. set up some parameters
year_list <- 1746 : 2100 
var_list <- read.csv( './input/selected_output_variables.csv', stringsAsFactors = F )
var_list <- var_list$variable

# -----------------------------------------------------------------------------
# 2. read in some basics

# ini template 
ini_con <- file( paste0( './input/template_hector_', rcpXX, '.ini' ) ) 
ini_template <- readLines( ini_con )
close( ini_con ) 

# parameter combination csv 
pc_df <- read.csv( './int-out/A.par4_combinations.csv', stringsAsFactors = F )

run_index_total_digits <- nchar( as.character( max( pc_df$run_index ) ) )  

# ----------------------------------------------------------------------------
# 3. run hector and deal with hector outputs 
result_file_name <- paste0( 'B.hector_run_results.txt' )
result_file_path_name <- paste0( pic_hectorSA_path, '/int-out/', rcpXX, '/', result_file_name )
result_file_con <- file( result_file_path_name, 'w' )

out_res_list <- lapply( 1 : nrow( pc_df ), function( i ) { 
  
  # generate a ini file 
  beta <- pc_df[ i, 'beta' ]
  q10 <- pc_df[ i, 'q10' ]
  s <- pc_df[i, 's']
  diff <- pc_df[ i, 'diff' ]
  run_index <- sprintf( paste0('%0', run_index_total_digits, 'd' ), pc_df[ i, 'run_index' ] )
  
  run_name <- paste0( 'hectorSA-', run_index )
  
  ini_name <- paste0( run_name, '.ini' )
  ini_file_path_name <- paste0( './int-out/', ini_name )
  ini_file <- file( ini_file_path_name )
  temp_ini <- ini_template 
  temp_ini[ 4 ] <- paste0( "run_name=", run_name )
  temp_ini[ 76 ] <- paste0( 'beta=', beta, '     \t; 0.36=about +20% @2xCO2' ) 
  temp_ini[ 77 ] <- paste0( 'q10_rh=', q10, '\t\t; respiration response Q10, unitless' )
  temp_ini[ 158 ] <- paste0( 'S=', s, ' \t\t\t\t; equilibrium climate sensitivity for 2xCO2, degC' )
  temp_ini[ 159 ] <- paste0( 'diff=', diff, '\t\t\t; ocean heat diffusivity, cm2/s' )
  writeLines( temp_ini, ini_file )
  close( ini_file )
  
  # copy the ini file into pic hector directory
  hector_ini_name_path <- paste0( pic_hector_path, '/input/', ini_name )
  file.copy( ini_file_path_name, hector_ini_name_path )
  file.remove( ini_file_path_name )
  
  # run hector
  setwd( pic_hector_path )
  system( 'pwd' )
  exp <- paste0( './source/hector ', hector_ini_name_path )
  system( exp )
  setwd( pic_hectorSA_path )
  file.remove( hector_ini_name_path )
  
  # output extraction and out df 
  out_stream_name <- paste0( 'outputstream_', run_name, '.csv' ) 
  out_stream_name_path <- paste0( pic_hector_path, '/output/', out_stream_name )
  
  outstream_df <- read.csv( out_stream_name_path, stringsAsFactors = F, skip = 1 )
  
  good_run_flag <- all( year_list %in% outstream_df$year ) 
  
  if ( good_run_flag ) { 
  
    temp_df <- outstream_df[ outstream_df$year %in% year_list, ]
    temp_df <- temp_df[ temp_df$variable %in% var_list, ]
    
    invisible( lapply( 1 : nrow( temp_df ), function( i ) { 
      temp_df_line <- unlist( temp_df[ i, ] )
      temp_df_line <- paste( temp_df_line, collapse = ',' )

      cat( temp_df_line, file = result_file_con, append = TRUE, sep="\n" )
      } ) ) 
  } 
  file.remove( out_stream_name_path )
  
  return( 'nothing to return' )
} ) 

close( result_file_con )