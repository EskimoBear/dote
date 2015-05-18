require 'pp'
require_relative '../lib/eson'

module TestHelpers

  extend self
  
  def get_valid_eson
    load_test_inputs('valid')
  end

  def get_unknown_special_form_program
    load_test_inputs('unknown_special_form')
  end

  def get_tokenizer_sample_program
    load_test_inputs('tokenizer_sample')
  end

  def get_empty_program
    "{}"
  end

  def get_invalid_program
    "{\"invalid\": (}"
  end

  def get_token_sequence(grammar=Eson::EsonGrammars.tokenizer_lang,
                         program=get_tokenizer_sample_program)
    Eson::TokenPass
      .tokenize_program(
        program,
        grammar)
      .verify_special_forms
  end

  def get_ast(token_sequence=get_token_sequence,
              grammar=Eson::EsonGrammars.tokenizer_lang)
    Eson::SyntaxPass.build_tree(
      token_sequence,
      grammar)
  end
  
  private

  def load_test_inputs(name)
    file = File.join('../../test/eson_inputs', "#{name}.eson")
    File.open(File.expand_path(file, __FILE__)).read 
  end
end
