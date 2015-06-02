module AST

  def convert_to_ast(tree)
    remove_alternation_rules(tree)
    remove_option_rules(tree)
    remove_repetition_rules(tree)
    reduce_array_set(tree)
    reduce_program_set(tree)
    reduce_string(tree)
    make_operators_root(tree)
  end

  def remove_alternation_rules(tree)
    tree.reduce_roots(:alternation)
  end

  def remove_option_rules(tree)
    tree.reduce_roots(:option)
  end

  def remove_repetition_rules(tree)
    tree.remove_roots(:repetition)
  end

  def reduce_array_set(tree)
    tree.remove_roots(:element_list)
    tree.remove_roots(:element_more)
    tree.remove_roots(:element_more_once)
    tree.delete_nodes(:element_divider)
    tree.delete_nodes(:array_start)
    tree.delete_nodes(:array_end)
    remove_nullable_child(tree, :array)
  end

  def remove_nullable_child(tree, tree_match)
    tree.find_all{|i| i === tree_match}
      .select{|i| i.has_child? :nullable}
      .select{|i| i.degree > 1}
      .map{|i| i.children}
      .each do |cl|
      cl.each {|t| t === :nullable ? t.delete_node(:nullable) : nil}
    end
    tree
  end

  def reduce_program_set(tree)
    tree.delete_nodes(:declaration_list)
    tree.delete_nodes(:declaration_more_once)
    tree.delete_nodes(:declaration_divider)
    tree.delete_nodes(:program_start)
    tree.delete_nodes(:program_end)
    remove_nullable_child(tree, :program)
  end

  def reduce_string(tree)
    tree.delete_nodes(:string_delimiter)
    remove_nullable_child(tree, :string)
  end

  def make_operators_root(tree)
    make_bind_trees(tree)
    make_apply_trees(tree)
    tree
  end

  def make_bind_trees(tree)
    attributes = tree.select{|i| i === :attribute}
    attribute_names = attributes.map{|a| a.children.first}
    colons = attributes.map{|a| a.children[1]}
    values = attributes.map{|a| a.children.last}
    attributes.zip(attribute_names, colons, values).each do |t|
      t_attribute = t.first
      t_colon = t[2]
      t_colon.name = :bind
      t_colon.make_tree_node
      t_colon.children.push(t[1]).push(t.last)
      t_colon.children.each{|i| i.parent = t_colon}
      t_attribute.children.delete_if{|i| !(i === t_colon.name)}
      t_attribute.reduce_root
    end
  end

  def make_apply_trees(tree)
    calls = tree.select{|i| i === :call}
    procs = calls.map{|a| a.children.first}
    colons = calls.map{|a| a.children[1]}
    args = calls.map{|a| a.children.last}
    calls.zip(procs, colons, args).each do |t|
      t_call = t.first
      t_colon = t[2]
      t_colon.name = :apply
      t_colon.make_tree_node
      t_colon.children.push(t[1]).push(t.last)
      t_colon.children.each{|i| i.parent = t_colon}
      t_call.children.delete_if{|i| !(i === t_colon.name)}
      t_call.reduce_root
    end
  end
end
