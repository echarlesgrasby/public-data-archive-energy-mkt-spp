[CmdletBinding()]
param(
	[Parameter(Mandatory=$False)]
	[string]
	$baseUrl = "https://portal.spp.org",			# default to download from portal.spp.org
	
	[Parameter(Mandatory=$False)]
	[boolean]
	$clobber = $False,								# default to not clobber any file already stored on local disk
	
	[Parameter(Mandatory=$False)]
	[int]									
	$baseDelay = 3,									# default to a delay of 3 seconds between download requests
	
	[Parameter(Mandatory=$False)]
	[string]
	$baseDownloadPath = "D:\pub_data_archive"		# default to a folder on my local D: drive
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
				The Unlicense

				Author 2026 Eric C. Grasby, MSIQ

				This is free and unencumbered software released into the public domain.

				Anyone is free to copy, modify, publish, use, compile, sell, or
				distribute this software, either in source code form or as a compiled
				binary, for any purpose, commercial or non-commercial, and by any
				means.

				In jurisdictions that recognize copyright laws, the author or authors
				of this software dedicate any and all copyright interest in the
				software to the public domain. We make this dedication for the benefit
				of the public at large and to the detriment of our heirs and
				successors. We intend this dedication to be an overt act of
				relinquishment in perpetuity of all present and future rights to this
				software under copyright law.

				THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
				EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
				MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
				IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
				OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
				ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
				OTHER DEALINGS IN THE SOFTWARE.

				For more information, please refer to <https://unlicense.org>
				
	----------------------------------------------------------------------------------------------
#>


function jitter_delay(){
	<#
		.SYNOPSIS
			Return a "semi-random" offset to jitter the download delay
	#>
	
	$x =  3, 5 `
	, 4.2, 10.24 `
	, 15.3, 9.366 `
	, 10.4, 0.426 `
	, 24.5, 10.583 `
	, 20.6, 0.652 `
	, 30.7, 10.733 `
	, 15.8, 20.8421 `
	, 12.9, 11.9777 `
	, 71.0, 1.115 `
	, 2.1, 25.245 `
	, 34.0, 32.425 `
	, 40.2, 4.783 `
	, 5.5, 15.69 `
	, 6.7, 20.888 `
	, 20.305, 20.803 `
	, 20.0, 25.9 | Get-Random

    return $x
}

function build_folder_file_listing_url([string]$data_category_name, [string]$download_year, [string]$download_month, [switch]$byDay=$False){
	<#
		.SYNOPSIS
			Takes in 3 string parameters and build a properly formatted Url ([string]) and return it to the caller
	#>
	
	if ($byDay){
		$download_url = "${baseUrl}/file-browser-api/?fsName=${data_category_name}&path=%2F${download_year}%2F${download_month}%2FBy_Day&type=folder";
	}else{
		$download_url = "${baseUrl}/file-browser-api/?fsName=${data_category_name}&path=%2F${download_year}%2F${download_month}&type=folder";
	}
	
	return $download_url;
}

function build_file_download_url([string]$data_category_name, [string]$download_year, [string]$download_month, [string]$file_to_fetch, [switch]$byDay){
	<#
		.SYNOPSIS
			Takes in 4 string parameters and build a properly formatted Url () and return it to the caller
	#>
    
    if ($byDay){
        $download_url = "${baseUrl}/file-browser-api/download/${data_category_name}?path=%2F${download_year}%2F${download_month}%2FBy_Day%2F${file_to_fetch}";
    }else{
        $download_url = "${baseUrl}/file-browser-api/download/${data_category_name}?path=%2F${download_year}%2F${download_month}%2F${file_to_fetch}";
    }
	
	return $download_url;
}

function build_output_path([string]$areaName, [string]$data_category_name, [string]$download_year, [string]$download_month, [string]$file_to_fetch){
	<#
		.SYNOPSIS
			Build the output path (on-disk) for where the downloaded file must be written to
	#>
	return "${baseDownloadPath}\${areaName}\${data_category_name}\${download_year}\${download_month}\${file_to_fetch}";
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
	
	# Add a separate delay, to ensure that we stay well within Terms of Use for downloading files
	$j1 = jitter_delay;
	$j2 = jitter_delay; 
	$downloadDelay = ($baseDelay + $j1 + $j2);
	
	
	if (! ${clobber}){
		if (Test-Path -Path $tgt_path){
			Write-Warning "${tgt_path} already exists and the clobber flag is not set. Skipping file download."; 
			return;
		}
	}
	
	Start-Sleep -Seconds $downloadDelay;
	
	# If we are not skipping the download, then perform the download.
	try{
		Invoke-WebRequest -Uri "${src_path}" -OutFile "${tgt_path}";
		Write-Output "				\-- File written to: ${tgt_path}";
	}catch{
		Write-Error "Failed to fetch file - ${_}";
	}
}

function main() {
	<#
		.SYNOPSIS
			Runs the main program and exits the script
	#>
	
	$download_target = [ordered]@{
		
		#sample folder listing Url --> gtxdh
		#sample file download Url  --> https://portal.spp.org/file-browser-api/download/day-ahead-fuel-on-margin?path=%2F2026%2F01%2FDA-FUEL-ON-MARGIN-202601240100.csv
		
		"day-ahead-market" = [ordered]@{
								 <#"da-lmp-by-bus" = [ordered]@{
													"2026" = @("01");
												};
								  
								  "da-lmp-by-location" = [ordered]@{
													"2026" = @("01");
												};
								  "market-clearing" = [ordered]@{
													"2026" = @("01");
												};
								  "virtual-clearing-by-moa" = [ordered]@{
													"2026" = @("01");
												};
                                   "day-ahead-fuel-on-margin" = [ordered]@{
                                                    "2026" = @("01");
                                                };#>
                                    "da-binding-constraints" = [ordered]@{
                                                    "2026" = @("01");
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
						
                        if ($category -in @("da-lmp-by-bus", "da-lmp-by-location", "da-binding-constraints")){
                            $folder_file_listing_url = build_folder_file_listing_url -data_category_name ${category} -download_year ${dl_year} -download_month ${dl_month} -byDay;
                        }else{
                            $folder_file_listing_url = build_folder_file_listing_url -data_category_name ${category} -download_year ${dl_year} -download_month ${dl_month};
                        }
						Write-Output "			\-- Fetch from: ${folder_file_listing_url}";
						
						$listing = build_folder_file_listing -download_url $folder_file_listing_url;
						
						<#
							Create archive path if it does not already exist
						#>
						$path_to_archive = "${baseDownloadPath}\${area}\${category}\${dl_year}\${dl_month}";
						if (!(Test-Path $path_to_archive)){
							New-Item -Type Directory $path_to_archive -Force
						}
						
						$jt_delay = jitter_delay;
						$delaySeconds = ($baseDelay + $jt_delay);
						Start-Sleep -Seconds $delaySeconds;
						
						<#
							Is there anything to process? If no, restart the loop
							Note: It's interesting.. 'continue' does not behave the way that you would expect it to inside of ForEach-Object (not like it does inside an actual foreach loop)
							'return' here actually behaves the way that we need it to.
						#>
						$found_file_len = $listing.Content.length
						$resp_status_code = $listing.StatusCode
						
						if (([int]$found_file_len -le 3) -or ([int]$resp_status_code -ne 200)){
							Write-Warning "No files found for ${category},${dl_year},${dl_month}";
							return;
							
						}else{
							
							<#
								Download each of the files, serially, from the result of the folder listing payload
							#>
							$listing.Content | ConvertFrom-Json | ForEach-Object {
								
								foreach($obj in $PSITEM){
									$filename_to_fetch = $obj.Name;

                                    if ($category -in @("da-binding-constraints")){
                                        $fetchUrl = build_file_download_url -data_category_name "${category}" -download_year "${dl_year}" -download_month "${dl_month}" -file_to_fetch "${filename_to_fetch}" -byDay;
                                    }else{
                                        $fetchUrl = build_file_download_url -data_category_name "${category}" -download_year "${dl_year}" -download_month "${dl_month}" -file_to_fetch "${filename_to_fetch}";
                                    }

									Write-Output "				\-- File to fetch:   ${fetchUrl}";
									$dwnl_path = build_output_path -areaName "${area}" -data_category_name "${category}" -download_year "${dl_year}" -download_month "${dl_month}" -file_to_fetch "${filename_to_fetch}";
									download_file -src_path "${fetchUrl}" -tgt_path "${dwnl_path}";
								}
							}
						}
						
						Start-Sleep -Seconds $delaySeconds;
				};
			};
		};
	} <# Finish iterating through ${download_target} #>
}

Write-Output "Script execution began at $(Get-Date)";
Write-Output "BaseDownloadPath is ${baseDownloadPath}"

$cont_resp = Read-Host "Press Y to continue"
if ($cont_resp -ne "Y") {
	Write-Output "Y not selected. Exiting script";
}else{
	# Run the script
	main
}

Write-Output "`n-- --";
Write-Output "Script completed at $(Get-Date)";
