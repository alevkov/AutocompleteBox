A subclass of UITextField that recognizes hashtags, @-mentions and relations (<>).

![Screenshot](https://ibb.co/Sn6hDCD)

Simply run the emulator and start typing away.

The view logic is in `Views/AutocompleteBox.swift`

## Current issues:

- Highlighting works only when autocompletion is in progress. Completed autocompletions are un-highlighted.
- Relation autocompletion needs to be revisited regarding the formatting, it is probably currently wrong.
