[CmdletBinding()]
param(
	[string]
	$baseUrl = "https://portal.spp.org",	# default to download from portal.spp.org
	
	[boolean]
	$clobber = $True,						# default to clobber any file already stored on local disk
	
	[int]									# default to a delay of 3 seconds between download requests
	$baseDelay = 3,
	
	[string]
	$baseDownloadPath
)
<#

	.SYNOPSIS
		This script is part of my dissertation work (specifically Chapter 4 - Proof of Concept Development).
		
		This dissertation is browsable at the following address:
		https://github.com/echarlesgrasby/dissertation/tree/master
			
		The purpose of this script is to iterate through the web endpoints defined in `$download_target` and download
		CSV files hosted on $baseUrl (this defaults to Southwest Power Pool's data assets that are open to the general public)
		to local disk. 
			
		The files are organized in a hierarchy similar to how they are stored on the web.
		
	----------------------------------------------------------------------------------------------
	
		TITLE:		archive_spp_public_data.ps1
	
		AUTHOR:		Eric C. Grasby, MSIQ
		DATE: 		1/25/2026
				
		INVOCATION:	Call this script directly from the command line, and ensure that you have set the appropriate download root.
					If folders do not already exist below the download root, this script will create them. 
					If a given file already exists, this script will clobber it.
				
		DISCLAIMER: This script is provided "AS IS", without warranty of any kind, express or implied, including (but not limited to)
					the warranties of merchantability, fitness for a particular purpose, and noninfringement.
					
					In no event shall the author be liable for any claim, damages, or other liability, whether in an action of contract,
					tort, or otherwise, arising from, out of, or in connection with this script or the use or other dealings in the script.
					
					The author assumes NO responsibility for how this script is used by third parties, including but not limited to excessive
					download activity, misuse of data, or violations of external service policies.
					
		RATE LIMITING:	To promote responsible use and to minimize impact on the public archive (of which this script downloads from) this 
						script is configured (or intended) to operate within conservative limits, such as:
					
							- Low request rates (1 request every 3..N seconds)
							- No configured burst downloads
						
						These limits are provided as general guidance only. Users should independently verify and adhere to the official usage
						and rate limit policies of the data provider.
					
	----------------------------------------------------------------------------------------------
	
		LICENSE
				MIT License

				Copyright (c) 2026 Eric C. Grasby, MSIQ

				Permission is hereby granted, free of charge, to any person obtaining a copy
				of this software and associated documentation files (the "Software"), to deal
				in the Software without restriction, including without limitation the rights
				to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
				copies of the Software, and to permit persons to whom the Software is
				furnished to do so, subject to the following conditions:
			
				The above copyright notice and this permission notice shall be included in all
				copies or substantial portions of the Software.
			
				THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
				IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
				FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
				AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
				LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
				OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
				SOFTWARE.	
				
	----------------------------------------------------------------------------------------------
#>


<#
		TODO - Features to add to this script:
		
		- generate folder structure (ignore if already exists)
		- implement build_list_of_files_to_download
		- download file
		- check if file already exists
		- boolean flag to clobber or ignore if file already exists
		- serial rate limit (no threading, just one single thread with a random delay of 3 seconds or greater)

#>

function jitter_delay(){
	<#
		.SYNOPSIS
			Return a "semi-random" offset to jitter the download delay
	#>
	return Get-Random @(
	  0.1, 0.114
	, 0.2, 0.24
	, 0.3, 0.366
	, 0.4, 0.426
	, 0.5, 0.583
	, 0.6, 0.652
	, 0.7, 0.733
	, 0.8, 0.8421
	, 0.9, 0.9777
	, 1.0
	); 
}

function build_folder_file_listing_url([string]$data_category_name, [string]$download_year, [string]$download_month){
	<#
		.SYNOPSIS
			Takes in 3 string parameters and build a properly formatted Url ([string]) and return it to the caller
	#>
	$download_url = "${baseUrl}/file-browser-api/?fsName=${data_category_name}&path=%2F${download_year}%2F${download_month}%2FBy_Day&type=folder";
	return $download_url;
}

function build_folder_file_listing([string]$download_url){
	<#
		.SYNOPSIS
			Takes in the payload from the GET request of a folder_file_listing_url ([string]), 
			process it into a POSH data structure, and return to the caller
	#>
	
	$response = Invoke-WebRequest -Uri "${download_url}" -Method Get -UseBasicParsing;
	return $response;
}

function download_file([string]$src_path, [string]$tgt_path){
	<#
		.SYNOPSIS
			Receives a Url and a local path. This downloads files from the remote path and writes it to local disk
	#>
}

function main() {
	<#
		.SYNOPSIS
			Runs the main program and exits the script
	#>
	
	$download_target = [ordered]@{
		#sample folder listing Url --> https://portal.spp.org/file-browser-api/?fsName=da-lmp-by-bus&path=%2F2024%2F09%2FBy_Day&type=folder
		#sample file download Url  --> https://portal.spp.org/file-browser-api/download/day-ahead-fuel-on-margin?path=%2F2026%2F01%2FDA-FUEL-ON-MARGIN-202601240100.csv
		"day-ahead-market" = [ordered]@{
								 "da-lmp-by-bus" = [ordered]@{"2026" = @("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12");
												   "2025" = @("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12");
												   "2024" = @("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12");
												   "2023" = @("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12");
												   "2022" = @("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12");
												   "2021" = @("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12");
												   "2020" = @("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12");
												   "2019" = @("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12");
												};
							  };
	};
	
	$download_target.GetEnumerator() | ForEach-Object {
		$area = $_.Name;
		Write-Output "Processing files for ${area}";
		
			$_.Value.GetEnumerator() | ForEach-Object {
				$category = $_.Name;
				Write-Output "|--category: ${category}";
				
				$_.Value.GetEnumerator() | ForEach-Object {
					$dl_year = $_.Name;
					Write-Output "	\--year: ${dl_year}";
					
					$_.Value.GetEnumerator() | ForEach-Object {
						$dl_month = $_;
						Write-Output "		\--month: ${dl_month}";
						
						$folder_file_listing_url = build_folder_file_listing_url -data_category_name ${category} -download_year ${dl_year} -download_month ${dl_month};
						Write-Output "			\-- Fetch from: ${folder_file_listing_url}";
						
						$jt_delay = $jitter_delay;
						$delaySeconds = $baseDelay + $jt_delay;
						
						$listing = build_folder_file_listing -download_url $folder_file_listing_url;
						
						Start-Sleep -Seconds $delaySeconds;
						
						<#
							Is there anything to process? If no, restart the loop
						#>
						$found_file_count = ($listing.Content | Measure-Object).Count
						$resp_status_code = $listing.StatusCode
						
						Write-Output "Count is ${found_file_count} and StatusCode is ${resp_status_code}"
						
						if (([int]$found_file_count -eq 0) -or ([int]$resp_status_code -ne 200)){
							Write-Warning "No files found for ${category},${dl_year},${dl_month}";
							continue;
						}else{
							
							<#
								Download each of the files, serially, from the result of the folder listing payload
							#>
							$listing.Content | ConvertFrom-Json | ForEach-Object {
								$PSITEM
							}
						}
						
						Start-Sleep -Seconds $delaySeconds;
				};
			};
		};
	} <# Finish iterating through ${download_target} #>
}

# Run the script
#main

Write-Output "BaseDownloadPath is ${baseDownloadPath}"
Write-Output "`n-- --";
Write-Output "Script completed at $(Get-Date)";

