module XRay
  # custom pattern matching for performance and the SDK use cases.
  module SearchPattern
    # Performs a case-insensitive wildcard match against two strings.
    # This method works with pseduo-regex chars; specifically ? and * are supported.
    # An asterisk (*) represents any combination of characters.
    # A question mark (?) represents any single character.
    # @param [String] pattern The regex-like pattern to be compared against.
    # @param [String] text The string to compare against the pattern.
    # @param case_insensitive A boolean flag. Default is true.
    def self.wildcard_match?(pattern:, text:, case_insensitive: true)
      return false unless pattern && text
      pattern_len = pattern.length
      text_len = text.length
      return text_len.zero? if pattern_len.zero?
      # Check the special case of a single * pattern, as it's common
      return true if pattern == '*'

      if case_insensitive
        # do not mutate original input
        pattern = pattern.downcase
        text = text.downcase
      end
      # Infix globs are relatively rare, and the below search is expensive.
      # Check for infix globs and, in their absence, do the simple thing.
      if !pattern.include?('*') || pattern.index('*') == pattern_len - 1
        return simple_wildcard_match? pattern: pattern, text: text
      end

      # The res[i] is used to record if there is a match between
      # the first i chars in text and the first j chars in pattern.
      # So will return res[textLength+1] in the end
      # Loop from the beginning of the pattern
      # case not '*': if text[i]==pattern[j] or pattern[j] is '?',
      # and res[i] is true, set res[i+1] to true, otherwise false.
      # case '*': since '*' can match any globing, as long as there is a true
      # in res before i, all the res[i+1], res[i+2],...,res[textLength]
      # could be true
      res = Array.new(text_len + 1)
      res[0] = true
      (0...pattern_len).each do |j|
        p = pattern[j]
        if p != '*'
          (text_len - 1).downto(0) do |i|
            res[i + 1] = res[i] && (p == '?' || (p == text[i]))
          end
        else
          i = 0
          i += 1 while i <= text_len && !res[i]
          (i..text_len + 1).each do |m|
            res[m] = true
          end
        end
        res[0] = res[0] && (p == '*')
      end
      res[text_len]
    end

    private_class_method

    def self.simple_wildcard_match?(pattern:, text:)
      j = 0
      pattern_len = pattern.length
      text_len = text.length
      (0...pattern_len).each do |i|
        p = pattern[i]
        # Presumption for this method is that globs only occur at end
        return true if p == '*'
        if p == '?'
          # No character to match
          return false if j == text_len
        else
          return false if j >= text_len || p != text[j]
        end
        j += 1
      end
      # Ate up all the pattern and didn't end at a glob, so a match
      # will have consumed all the text
      j == text_len
    end
  end
end
