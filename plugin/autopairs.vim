vim9script

const skip_pattern = '[[:keyword:]]'
const default_pairs: dict<string> = {
  '(': ')',
  '[': ']',
  '{': '}',
}
const default_quotes: dict<string> = {
  '"': '"',
  "'": "'",
}

const all_pairs = extendnew(default_pairs, default_quotes)

const left_key = "\<C-g>U\<Left>"
const right_key = "\<C-g>U\<Right>"

var line_text: string
var current_col: number
var char_after: string
var char_before: string

def SetContext()
  line_text = getline('.')
  current_col = col('.')
  char_after = CharAfterCursor()
  char_before = CharBeforeCursor()
enddef

def InSkipGroup(): bool
  var syn_groups: list<string>
  var synstack: list<number> = synstack('.', current_col)
  # At the end of the comments synstack is empty, so workaround
  # is to check synstack of the previous position only for comment
  if empty(synstack) && len(line_text) == current_col - 1
    synstack = synstack('.', current_col - 1)
    syn_groups = ['comment']
  else
    syn_groups = ['string', 'comment']
  endif

  var synname: string
  for synID: number in synstack
    synname = synIDattr(synID, 'name')
    for group in syn_groups
      if synname =~? group
        return true
      endif
    endfor
  endfor

  return false
enddef

def CharBeforeCursor(): string
  return strpart(line_text, current_col - 2, 1)
enddef

def CharAfterCursor(): string
  return strpart(line_text, current_col - 1, 1)
enddef

def SkipInsertPair(char: string): bool
  if char_before == '\'
    return true
  endif

  if char =~ "[\"']" && char == char_before
    return true
  endif

  return char_after =~ skip_pattern || InSkipGroup()
enddef

def InsertPair(char: string): string
  if char =~ "[\"']" && char == char_after
    return ClosePair(char)
  endif

  # just jump over the char if it is the same as the inserted
  if char == char_after
    return right_key
  endif

  if SkipInsertPair(char)
    return char
  else
    return char .. all_pairs[char] .. left_key
  endif
enddef

def ClosePair(char: string): string
  if char =~ "[\"']" && char_before == '\'
    return char
  endif

  if char == char_after
    return right_key
  else
    return char
  endif
enddef

def CharsAroundCursor(size: number = 1): list<string>
  const col = col('.') - 1
  const line = getline('.')

  # return nothing at the end and start of the line
  if col == 0 || col == len(line)
    return ['', '']
  endif

  const start = max([0, col - size])
  return [slice(line, start, col), slice(line, col, col + size)]
enddef

def HasPairAtCursor(pairs: dict<string>, with_space: bool = false): bool
  var before: string
  var after: string
  var space_patern: string = ''
  if with_space
    [before, after] = CharsAroundCursor(2)
    space_patern = '\s\?'
  else
    [before, after] = CharsAroundCursor(1)
  endif

  if !empty(before)
    var match: string
    var space: string
    for p in keys(pairs)
      match = matchstr(before, $'\V{p}{space_patern}\$')
      if !empty(match)
        space = slice(match, -1) == ' ' ? '\s' : ''
        if after =~ $'^{space}{pairs[p]}'
          return true
        endif
      endif
    endfor
  endif

  return false
enddef

def Delete(key: string): string
  if HasPairAtCursor(all_pairs, true)
    return $"\<Del>{key}"
  else
    return key
  endif
enddef

def CloseWithContext(char: string): string
  SetContext()
  return ClosePair(char)
enddef

def InsertWithContext(char: string): string
  SetContext()
  return InsertPair(char)
enddef

inoremap <expr> ) CloseWithContext(')')
inoremap <expr> } CloseWithContext('}')
inoremap <expr> ] CloseWithContext(']')
inoremap <expr> ( InsertWithContext('(')
inoremap <expr> { InsertWithContext('{')
inoremap <expr> [ InsertWithContext('[')
inoremap <expr> " InsertWithContext('"')
inoremap <expr> ' InsertWithContext("'")

inoremap <expr> <BS> Delete("\<BS>")
inoremap <expr> <C-h> Delete("\<C-h>")
inoremap <expr> <C-w> Delete("\<C-w>")
inoremap <expr> <space> HasPairAtCursor(default_pairs) ? "\<space>\<space>" .. left_key : "\<space>"

defcompile
