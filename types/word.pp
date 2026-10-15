# @summary A single command-line word: no whitespace.
type Homer::Word = Pattern[/\A\S+\z/]
