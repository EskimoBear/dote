require 'oj'
require 'pry'
require_relative 'token_pass'

module Dote::TokenPass

  module Tokenizer

    InvalidLexeme = Class.new(StandardError)
    TokenizationIncomplete = Class.new(StandardError)

    # @!attribute lexeme
    #   @return [Symbol] characters representing the symbol
    # @!attribute name
    #   @return [Symbol] name of the JSON symbol
    JsonSymbol = Struct.new :lexeme, :name

    # Convert an eson program into a sequence of eson tokens
    # @param eson_program [String] string provided to Dote#read
    # @return [TokenSeq] A token sequence
    # @raise [TokenizationIncomplete] token sequence does not contain
    #   all the characters in the program
    # @eskimobear.specification
    #  Dote token set, ET is a set of the eson terminals
    #  Dote token, et is a sequence of characters existing in ET
    #  label(et) maps the character sequence to the name of the matching
    #    eson terminal symbol
    #  Input program, p, a valid JSON string
    #  Input sequence, P, a sequence of characters in p
    #  Token sequence, T
    #
    #  Init : length(P) > 0
    #         length(T) = 0
    #  Next : et = P - 'P
    #         T' = T + label(et)
    def tokenize_program(eson_program, grammar)
      eson_program.freeze
      program_json_hash = Oj.load(eson_program)
      program_char_seq = get_program_char_sequence(program_json_hash)
      json_symbol_seq = get_json_symbol_sequence(program_json_hash)
      token_seq = json_symbols_to_tokens(json_symbol_seq, program_char_seq, grammar)
      unless program_char_seq.empty?
        raise TokenizationIncomplete,
              tokenization_incomplete_error_message
      end
      token_seq
    end

    private

    def tokenization_incomplete_error_message
      "The sequence of eson tokens generated by the" \
      " compiler only partially represents the program." \
      " Compilation cannot continue; please file a bug" \
      " report providing the eson program tried."
    end

    def get_program_char_sequence(hash)
      seq = Array.new
      compact_string = Oj.dump(hash)
      compact_string.each_char {|c| seq << c}
      seq
    end

    def get_json_symbol_sequence(hash)
      Array.new.push(JsonSymbol.new(:"{", :object_start))
        .push(members_to_json_symbols(hash))
        .push(JsonSymbol.new(:"}", :object_end))
        .flatten
    end

    def members_to_json_symbols(json_pairs)
      seq = Array.new
      unless json_pairs.empty?
        seq.push pair_to_json_symbols(json_pairs.first)
        rest = json_pairs.drop(1)
        unless rest.empty?
          rest.each_with_object(seq) do |i, seq|
            seq.push(JsonSymbol.new(:",", :member_comma))
              .push(pair_to_json_symbols(i))
          end
        end
      end
      seq
    end

    def pair_to_json_symbols(json_pair)
      json_value = json_pair[1]
      value = value_to_json_symbols(json_value)
      Array.new.push(JsonSymbol.new(json_pair.first, :JSON_key))
        .push(JsonSymbol.new(:":", :colon))
        .push(value)
        .flatten
    end

    def value_to_json_symbols(json_value)
      if json_value.is_a? Hash
        get_json_symbol_sequence(json_value)
      elsif json_value.is_a? Array
        array_to_json_symbols(json_value)
      else
        JsonSymbol.new(json_value, :JSON_value)
      end
    end

    def array_to_json_symbols(json_array)
      seq = Array.new.push(JsonSymbol.new(:"[", :array_start))
      unless json_array.empty?
        seq.push(value_to_json_symbols(json_array.first))
        unless json_array.drop(1).empty?
          json_array.drop(1).each do |i|
            seq.push(JsonSymbol.new(:",", :array_comma))
            seq.push(value_to_json_symbols(i))
          end
        end
      end
      seq.push(JsonSymbol.new(:"]", :array_end))
    end

    def json_symbols_to_tokens(json_symbol_seq, char_seq, grammar)
      envs = grammar.env_init
      json_symbol_seq
        .each_with_object(Dote::TokenPass::TokenSeq.new) do |symbol, seq|
        case symbol.name
        when :object_start
          update_json_and_char_seqs(
            grammar.get_rule(:program_start).make_token(symbol.lexeme, envs),
            seq,
            char_seq,
            envs,
            grammar)
        when :object_end
          update_json_and_char_seqs(
            grammar.get_rule(:program_end).make_token(symbol.lexeme, envs),
            seq,
            char_seq,
            envs,
            grammar)
        when :array_start
          update_json_and_char_seqs(
            grammar.get_rule(:array_start).make_token(symbol.lexeme, envs),
            seq,
            char_seq,
            envs,
            grammar)
        when :array_end
          update_json_and_char_seqs(
            grammar.get_rule(:array_end).make_token(symbol.lexeme, envs),
            seq,
            char_seq,
            envs,
            grammar)
        when :colon
          update_json_and_char_seqs(
            grammar.get_rule(:colon).make_token(symbol.lexeme, envs),
            seq,
            char_seq,
            envs,
            grammar)
        when :array_comma
          update_json_and_char_seqs(
            grammar.get_rule(:element_divider).make_token(symbol.lexeme, envs),
            seq,
            char_seq,
            envs,
            grammar)
        when :member_comma
          update_json_and_char_seqs(
            grammar.get_rule(:declaration_divider).make_token(symbol.lexeme, envs),
            seq,
            char_seq,
            envs,
            grammar)
        when :JSON_key
          tokenize_json_key(symbol.lexeme, seq, char_seq, envs, grammar)
        when :JSON_value
          tokenize_json_value(symbol.lexeme, seq, char_seq, envs, grammar)
        end
      end
    end

    #Accumulator function for sequences and environment variables
    #used in the tokenization process.
    #@param token [Token]
    #@param token_seq [TokenSeq]
    #@param char_seq [Array]
    def update_json_and_char_seqs(token, token_seq, char_seq, envs, grammar)
      char_seq.slice!(0, token.lexeme.size)
      grammar.eval_s_attributes(envs, token, token_seq)
      token_seq.push(token)
    end

    def tokenize_json_key(json_key, seq, char_seq, envs, grammar)
      lexer([:special_form_identifier,
             :unreserved_procedure_identifier,
             :attribute_name],
            get_delimited_string(json_key),
            seq,
            char_seq,
            envs,
            grammar)
    end

    def get_delimited_string(string)
      "\"".concat(string).concat("\"")
    end

    def lexer(terminals, string, seq, char_seq, envs, grammar)
      matched_terminal = terminals.detect{|i| grammar.get_rule(i).match(string)}
      if matched_terminal.nil?
        raise InvalidLexeme, lexer_error_message(string)
      else
        update_json_and_char_seqs(
          grammar.get_rule(matched_terminal).match_token(string, envs),
          seq,
          char_seq,
          envs,
          grammar)
      end
    end

    def lexer_error_message(string)
      "The string - \n\"#{string}\"\ncould not be broken up into tokens." \
      " It does not match any of the valid tokens in eson."
    end

    def tokenize_json_value(json_value, seq, char_seq, envs, grammar)
      if json_value.is_a? TrueClass
        update_json_and_char_seqs(
          grammar.get_rule(:true).make_token(json_value.to_s, envs),
          seq,
          char_seq,
          envs,
          grammar)
      elsif json_value.is_a? FalseClass
        update_json_and_char_seqs(
          grammar.get_rule(:false).make_token(json_value.to_s, envs),
          seq,
          char_seq,
          envs,
          grammar)
      elsif json_value.is_a? Numeric
        update_json_and_char_seqs(
          grammar.get_rule(:number).make_token(json_value.to_s, envs),
          seq,
          char_seq,
          envs,
          grammar)
      elsif json_value.nil?
        update_json_and_char_seqs(
          grammar.get_rule(:null).make_token(:null, envs),
          seq,
          char_seq,
          envs,
          grammar)
      elsif json_value.is_a? String
        tokenize_json_string(
          get_delimited_string(json_value),
          seq,
          char_seq,
          envs,
          grammar)
      end
    end

    def tokenize_json_string(json_string, seq, char_seq, envs, grammar)
      lexer(
        [:string_delimiter,
         :variable_identifier,
         :word_form],
        json_string,
        seq,
        char_seq,
        envs,
        grammar)
      rest = get_rest(json_string, seq)
      unless rest.empty?
        tokenize_json_string(rest, seq, char_seq, envs, grammar)
      end
    end

    def get_rest(string, seq)
      matched_string = seq.last.lexeme
      string[matched_string.size..-1]
    end
  end
end
