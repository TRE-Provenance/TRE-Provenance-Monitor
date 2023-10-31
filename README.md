# TRE PROVENANCE MONITOR

## Background
Currently Analysts and Leads conduct manual checks of input, intermediary and output files at each stage of the process workflow which is time consuming and error prone, however, due to the almost serial nature of checks it could lend itself to automation to remove errors, avoid human error and aid and speed up the data delivery.

## Scope
Due to the current set up in Grampian Data Safe Haven where the NHS and University Safe Haven environments are completely separated the solution is limited to the University side assuming that the NHS side produces the required provenance trace independently. While the proposed solution could also be utilised on the NHS side, it would require further development to include other project workflow stages and the associated complexity.

## Solution
This part focuses on providing a set of scripts that scan directories and files to infer activities that took place within a project and create a provenance trace. In addition, they generate each data file metadata and summary statistics to be displayed and used for further checks.
While theoretically, the scripts could be used to monitor directories continuously, it would require more resources to run and cause extensive power usage. While the implementation was investigated for such an approach, it emerged that it would introduce further constraints and limitations in terms of environment set up and resulting cyber security risks and therefore a run-on-demand solution was implemented at this time.
Due to the limitations and ambiguity caused by creating, copying, and moving files between systems and folders, the scripts impose a rigid folder structure to successfully infer activities that took place in each project. The folder structure, while being prescriptive, allows more flexibility in terms of filename convention than using highly complex logic or machine learning to infer the data travel history and by extension also bypasses the issues caused by the file/release versioning.
## Requirements
The PowerShell environment utilised in the development:
Name|Value                                                                                                 
----|                           -----                                                                                                 
PSVersion                      |5.1.17763.4974                                                                                        
PSEdition                      |Desktop                                                                                               
PSCompatibleVersions           |{1.0, 2.0, 3.0, 4.0...}                                                                               
BuildVersion                   |10.0.17763.4974                                                                                       
CLRVersion                     |4.0.30319.42000                                                                                       
WSManStackVersion              |3.0                                                                                                   
PSRemotingProtocolVersion      |2.3                                                                                                   
SerializationVersion           |1.1.0.1 

The main requirement for the script to run successfully is the adherence to the folder structure described below.

# Folder structure
In general, the folder structure involves 5 stages: import, export, check, sign off and release and since the workflow is sequential each stage folder has a prefix to assign the ordering.

```tree
└── Project_[123]
	├── 01_Imported
	|	├── Task_01_[YYYY-MM-DD]
	|	|	├── File 1
	|	|	├── File 2
	|	|	└── etc
	|	└── Task_02_[YYYY-MM-DD]
	|		├── File 1
	|		├── File 2
	|		└── etc
	├── 02_Exported
	|	├── Task_01_[YYYY-MM-DD]
	|	|	├── File 1
	|	|	├── File 2
	|	|	└── etc
	|	└── Task_02_[YYYY-MM-DD]
	|		├── File 1
	|		├── File 2
	|		└── etc
	├── 03_Checked
	|	└── Task_01_[YYYY-MM-DD]
	|		├── File 1
	|		├── File 2
	|		└── etc
	├── 04_Signed_Off
	|	└── Task_01_[YYYY-MM-DD]
	|		├── File 1
	|		├── File 2
	|		└── etc
	└── 05_Released
	 	└── Task_01_[YYYY-MM-DD]
	 		├── File 1
	 		├── File 2
	 		└── etc
```
Each stage folder (01_Imported, 02_Exported etc) should follow the same convention and must contain ordering numbers. Those folders are static and should be consistent between projects.

Task folder name template is dynamic, however, as it is used for linking inputs to outputs between stages it must be consistent across stages. For example if File 1 and File 2 in the import stage were used to generate File 1 and File 2 in the export stage, each stage task folder must share the task number and only the date stamps can differ.

[Task]_[0-9]_[YYYY-MM-DD]

## Special files
There are two types of files that are treated slightly differently
•	Data Linkage Plan (DLP)
•	Link

Data Linkage Plan is generated on the NHS side and contains the project requirements such as the list of data sources, requested variables and constraints e.g. date range. That information is then subsequently used to find and flag any mismatches between requested and outputted variables.

Link file contains the mapping between any pseudo-IDs distributed across different datasets and is only imported for the linkage purpose and therefore doesn’t pass through any of the stages as output. However, the summary descriptive statistics are still generated.

## Example data flow case scenarios
![image](https://github.com/TRE-Provenance/TRE-Provenance-Monitor/assets/149473613/a10c2d5f-1220-4684-a87c-69032829d212)

If there is no task folder in the import stage related to the same task, then the assumption is that the DLP and Link files haven't changed and therefore all the import folders from previous tasks are scanned and the most recent one found is assumed to be the input to linkage.
For example, the Case 4 in the image above - Task_04 assumes that the DLP and Link files from Task_03 are inputs.

# Limitations
- Only comma delimited data files are currently supported
- The tool only works with a rigid folder structure
- The activity date stamps depend on the folder structure
- Parallel file processing not yet implemented
- Min and max variable constraints currently support dates only
