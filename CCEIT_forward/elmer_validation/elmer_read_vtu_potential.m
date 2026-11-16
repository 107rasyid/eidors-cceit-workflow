function phi = elmer_read_vtu_potential(vtu_file)
% ELMER_READ_VTU_POTENTIAL Read Elmer's real and imaginary nodal potential.
% Purpose: extract the harmonic scalar field from Elmer's raw-appended VTU.
% Inputs: vtu_file, path to one Elmer VTU result.
% Outputs: phi, complex nodal potential in VTU point order.
% Manuscript ref: Section III, independent Elmer forward-solver validation.

fid = fopen(vtu_file, 'rb');
if fid < 0
    error('elmer_read_vtu_potential: cannot open %s', vtu_file);
end
cleanup = onCleanup(@() fclose(fid));
bytes = fread(fid, Inf, '*uint8')';
if isempty(bytes)
    error('elmer_read_vtu_potential: empty VTU file: %s', vtu_file);
end

raw_text = char(bytes);
tag = '<AppendedData encoding="raw">';
tag_at = strfind(raw_text, tag);
if isempty(tag_at)
    error('elmer_read_vtu_potential: raw appended data missing in %s', vtu_file);
end
header_text = raw_text(1:tag_at(1)-1);
data_at = tag_at(1) + numel(tag);
while data_at <= numel(bytes) && any(bytes(data_at) == uint8([9 10 13 32]))
    data_at = data_at + 1;
end
if data_at > numel(bytes) || bytes(data_at) ~= uint8('_')
    error('elmer_read_vtu_potential: appended-data sentinel missing in %s', vtu_file);
end
data_base = data_at + 1;

phi_re = elmer_vtu_point_scalar(bytes, header_text, data_base, 'potential', vtu_file);
phi_im = elmer_vtu_point_scalar(bytes, header_text, data_base, 'potential im', vtu_file);
if numel(phi_re) ~= numel(phi_im)
    error('elmer_read_vtu_potential: real/imaginary field size mismatch in %s', vtu_file);
end
phi = phi_re + 1i*phi_im;

end
