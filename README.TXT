GetSubs is a subtitles extracting batch. It requires installed 
.NET Framework and MKVToolNix.

Some TVs have problems with subtitles inside MKV container.
This batch allows mass file processing to extract appropriate 
subtitles and save them near a source file with the same name
and removed BOM.

Examples of usage

getsubs.bat
-----------
Search current folder and all subfolders for mkv files. For
each file get all subtitles tracks which language is "eng" or
not specified or "und". Sort appropriate subtitles tracks by 
language priority then by file size. Save the first appropriate
subtitles track near the source file.

getsubs.bat "d:\my movies"
--------------------------
Do the same thing with mkv files in "d:\my movies" folder and
all subfolders.

getsubs.bat "movie.mkv"
-----------------------
Do the same thing with "movie.mkv" file in current folder.

getsubs.bat "movie.mkv" -l rus eng null
---------------------------------------
Extract subtitles for "movie.mkv" file. Look for russian, 
english and not specified language subtitles tracks. Russian 
subtitles has the highest priority so if it exists than all 
others will be ignored.

getsubs.bat "movie.mkv" -l rus eng null -t 1
--------------------------------------------
Do the same thing, but extract the second appropriate subtitles
track.

Language codes
--------------
https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes
