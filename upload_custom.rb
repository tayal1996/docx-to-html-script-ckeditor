# rubocop:disable Layout/LineLength, Style/MixinUsage, Metrics/AbcSize, Metrics/MethodLength
require 'base64'
include AwsHelper

system('mkdir -p public/uploads/gp_doc')

def count_em(str, substr)
  str.scan(/(?=#{substr})/).count
end

def find_and_convert_table_to_code_block_v2(html, code_block_language = 'language-plaintext')
  all_tables = html.scan(%r{<figure class="table".*?<\/figure>})
  all_tables = all_tables.select do |atable|
    atable = atable.gsub(%r{<tr[^>]*><td[^>]*>(?:<p[^>]*>)?&nbsp;(?:<\/p>)?<\/td><\/tr>}, '')
    count_em(atable, '</tr>') == 1 && count_em(atable, '</td>') == 1 && count_em(atable, '<img src=').zero?
  end
  map_table_to_norm_table = {}
  all_tables.each do |atable|
    map_table_to_norm_table[atable] = atable.gsub('<tr><td>&nbsp;</td></tr>', '')
                                            .gsub('<p>&nbsp;</p>', "\r\n")
                                            .gsub('&nbsp;', ' ')
                                            .gsub('</p>', "\r\n")
                                            .gsub(/<.*?>/, '')
  end
  map_table_to_norm_table.each do |k, v|
    html = html.gsub(k, "<pre><code class=\"#{code_block_language}\">#{v}</code></pre>")
  end
  html
end

###################################################################

def find_and_convert_base64_to_s3_links_v2(html, html_file_name = '')
  i = 0
  base_url = ''
  map_base64_to_image_s3_url = {}
  all_image_tags = html.scan(/(?<=<img src=")(.*?)(?=" alt)/).flatten

  all_image_tags.each do |possible_base_url|
    next if possible_base_url.exclude?('base64')

    i += 1
    base_url = possible_base_url
    base64_image = base_url.split(';base64,')[1]
    image_file_name = "#{html_file_name.split('.')[0].gsub(/[[:space:]]/, '')}_#{SecureRandom.hex(6)}_#{i}.png"
    image_file_path = Rails.root.join('public', 'uploads', 'gp_doc', image_file_name)
    File.open(image_file_path, 'wb') do |file|
      Rails.logger.info "writing to file #{image_file_path}"
      file.write(Base64.decode64(base64_image))
    end

    content_type = 'image/png'
    send_to_amazon(
      image_file_path,
      ENV['NINJAS_FILES_BUCKET'],
      content_type: content_type,
      cache_control: 'public,max-age=31540000'
    )

    File.delete(image_file_path)
    map_base64_to_image_s3_url[base_url] = "https://ninjasfilestest.s3.amazonaws.com/#{image_file_name}"
    map_base64_to_image_s3_url[base_url] = change_domain(map_base64_to_image_s3_url[base_url]) if ENV['RAILS_ENV'] == 'production'
  end

  map_base64_to_image_s3_url.each do |k, v|
    html = html.gsub(k, v)
  end
  html
end

#########################################

def find_and_fix_spacing_issues(html)
  html = html.gsub(%r{(<p[^>]*(?:><span[^>]*)?>&nbsp;(?:<\/span>)?<\/p>){3,}}, '\1')
  html = html.gsub(%r{(<p[^>]*><a[^>]*><\/a>&nbsp;<\/p>){3,}}, '\1')
  html = html.gsub(/^<p style="text-align: justify;(.*)/, '<p style="\1')
  html
end

###############################################

def find_and_remove_first_image_height(html)
  image_tag_match = html.match(%r{<img src=".*?\/>})
  return html if image_tag_match.nil?

  first_image_tag = image_tag_match[0]
  removed_height = first_image_tag.gsub(/height(=".*?"|:.*?px)/, '')
  html = html.gsub(first_image_tag, removed_height)
  html
end

###############################################

def save_html_file(html, converted_html_file_path)
  File.open(converted_html_file_path, 'wb') do |file|
    Rails.logger.info "writing to file #{converted_html_file_path}"
    file.write(html)
  end
end

###############################################

@code_block_language_map = {}
def get_code_block_language(guided_path_id)
  return @code_block_language_map[guided_path_id] if @code_block_language_map[guided_path_id].present?

  code_block_language_available = { 'c#': 'cs',
                                    'c++': 'cpp',
                                    'css': 'css',
                                    'diff': 'diff',
                                    'html': 'html',
                                    'javascript': 'javascript',
                                    'java': 'java',
                                    'php': 'php',
                                    'python': 'python',
                                    'ruby': 'ruby',
                                    'typescript': 'typescript',
                                    'xml': 'xml' }

  @guided_path = GuidedPath.find_by(id: guided_path_id)
  code_block_language = 'language-plaintext'
  @code_block_language_map[guided_path_id] = code_block_language
  return @code_block_language_map[guided_path_id] if @guided_path.blank?

  title = @guided_path.title.downcase
  code_block_language_available.each do |key, value|
    if title.include?(key.to_s)
      code_block_language = "language-#{value}"
      break
    end
  end
  @code_block_language_map[guided_path_id] = code_block_language
  @code_block_language_map[guided_path_id]
end

# conversion script below -

notes_to_external_doc_links = {}
reverse_map = {}
notes_to_external_doc_links.each do |note_id, external_doc_link|
  doc_file_id = external_doc_link.scan(%r{(?<=https:\/\/docs.google.com\/document\/d\/)(.*?)(?=\/edit)}).flatten[0]
  doc_file_name = "note_#{note_id}.docx"
  doc_file_path = Rails.root.join('public', 'uploads', 'gp_doc', doc_file_name)
  google_doc_api_key = 'AIzaAyDYSRsV4kfC6gZrXcLoB-lAbFYcZxfoKa4' # please add google drive/docs api key with permission here, this is only sample
  system("curl -L 'https://docs.google.com/document/d/#{doc_file_id}/export?format=doc&key=#{google_doc_api_key}' --output #{doc_file_path}")
  system("node importtoword.js #{doc_file_name}")
  html_file_name = "note_#{note_id}.html"
  html_file_path = Rails.root.join('public', 'uploads', 'gp_doc', html_file_name)
  html = File.read(html_file_path)
  image_converted_html = find_and_convert_base64_to_s3_links_v2(html, html_file_name)
  code_block_language = 'language-plaintext' || get_code_block_language(reverse_map[note_id])
  table_and_image_converted_html = find_and_convert_table_to_code_block_v2(image_converted_html, code_block_language)
  spacing_fixed_converted_html = find_and_fix_spacing_issues(table_and_image_converted_html)
  final_converted_html = find_and_remove_first_image_height(spacing_fixed_converted_html)
  converted_html_file_path = Rails.root.join('public', 'uploads', 'gp_doc', "converted_#{html_file_name}")
  save_html_file(final_converted_html, converted_html_file_path)
end

update_arr = []
Note.where(id: notes_to_external_doc_links.keys).each do |note|
  next if note.external_doc_link.blank?

  html_file_name = "converted_note_#{note.id}.html"
  html_file_path = Rails.root.join('public', 'uploads', 'gp_doc', html_file_name)
  final_converted_html = File.read(html_file_path)

  note.notes_html = final_converted_html
  update_arr.append(note)
  system("rm #{html_file_path}")
end
Note.import! update_arr, on_duplicate_key_update: [:notes_html], batch_size: 200

# rubocop:enable Layout/LineLength, Style/MixinUsage, Metrics/AbcSize, Metrics/MethodLength
