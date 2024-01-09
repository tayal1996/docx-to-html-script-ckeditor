# docx-to-html-script-ckeditor
* To convert many docx files to html files via importWord api of ckeditor. 
* Also the script fix the following issues on the converted html - 
  * Fix image base64 to s3 image, will have to define send_to_amazon method
  * Fix codeblocks of the converted html, since the importWord feature makes all codeblocks into tables of 1x1 size
  * Fix spacing issues on the converted html
  * Would also recommend to save the converted html in ckeditor once to fix other minor formating issues
