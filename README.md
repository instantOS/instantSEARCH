# instantSEARCH

instantSEARCH is a file search utility with

- A Custom file opener
- File history
- Regex Support

It is a GUI for the plocate algorithm which allows to search through millions of files in less than a second. It comes with a custom file opener that allows meaningfully working with the results of the search.

## Installation 

### Pacman

instantSEARCH is preinstalled on instantOS and available from the repo https://packages.instantos.io

### ibuild

When the instantOS dev tools are installed instantsearch can be updated from master using 
```sh
ibuild install instantsearch
```

### Git
```sh
git clone https://github.com/instantSEARCH
cd instantSEARCH
sudo make install
```

## planned features

- show file icon

## Requirements

- instantmenu
- plocate
- instantutils
