## code to prepare `DATASET` dataset goes here

# TODO: move stables_llama to package dataset
stables_llama_df <- targets::tar_read(stables_llama)
usethis::use_data(stables_llama_df, overwrite = TRUE)
