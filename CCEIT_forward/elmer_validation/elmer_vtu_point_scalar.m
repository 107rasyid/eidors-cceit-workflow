function values = elmer_vtu_point_scalar(bytes, header_text, data_base, field_name, vtu_file)
% ELMER_VTU_POINT_SCALAR Extract one Float64 point array from raw-appended VTU.
% Purpose: decode a named scalar array stored in VTK XML appended binary data.
% Inputs: bytes, raw VTU bytes; header_text, XML header; data_base, first payload
%         byte; field_name, DataArray Name; vtu_file, source path for errors.
% Outputs: values, double column vector.
% Manuscript ref: Section III, independent Elmer forward-solver validation.

escaped_name = regexptranslate('escape', field_name);
pattern = ['<DataArray[^>]*Name="' escaped_name '"[^>]*offset="([0-9]+)"'];
tokens = regexp(header_text, pattern, 'tokens', 'once');
if isempty(tokens)
    error('elmer_vtu_point_scalar: field "%s" missing in %s', field_name, vtu_file);
end
offset = str2double(tokens{1});
length_pos = data_base + offset;
if length_pos + 7 > numel(bytes)
    error('elmer_vtu_point_scalar: invalid data offset for "%s" in %s', field_name, vtu_file);
end
% Elmer's VTK writer uses the default UInt32 appended-data length header.
block_length = double(typecast(uint8(bytes(length_pos:length_pos+3)), 'uint32'));
first_value = length_pos + 4;
last_value = first_value + block_length - 1;
if last_value > numel(bytes) || mod(block_length, 8) ~= 0
    error('elmer_vtu_point_scalar: invalid Float64 block for "%s" in %s', field_name, vtu_file);
end
values = typecast(uint8(bytes(first_value:last_value)), 'double')';
end
