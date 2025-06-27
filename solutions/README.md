# Solutions Directory

This directory will contain your unpacked Power Platform solutions for version control.

## Structure

```
solutions/
├── YourSolutionName/
│   ├── Other/
│   ├── WebResources/
│   ├── Workflows/
│   ├── Entities/
│   ├── OptionSets/
│   ├── Roles/
│   └── Solution.xml
└── README.md
```

## Usage

- Unpacked solutions from the dev environment are stored here
- These files are version controlled
- Changes can be tracked and reviewed through Git
- Solutions are packed from here for deployment

## Git Ignore Recommendations

Add these to your `.gitignore` if you want to exclude certain files:

```
# Exclude temp files
solutions/**/*.tmp
solutions/**/*.log

# Exclude large binary files (optional)
solutions/**/WebResources/**/*.dll
```
