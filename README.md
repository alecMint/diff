diff
====

sh ../diff/diff.sh -a alec,harold -o -w -t 7 -b


* -a authors override
* -o open relevant files
* -w write HEAD files
* -t cutoff time for authorship (days ago)
* -b makes new branch off of production tag


With all the options set...
1. Compares HEAD of current repo with the tag checked out in production
2. Runs through all the files and attempts to determine whether it is relevant (i.e. you authored a commit recently)
3. Makes a copy of the HEAD version of each file
4. Opens the original and copy in your default editor
5. Saves a git diff log of only the relevant files
6. Creates a new branch based off the production tag with the letter incremented and prefixed with "tag_"


To Do
- [ ] gitignored config file to override default validOffers
