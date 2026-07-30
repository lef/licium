export function selectLoginSubject({
  credentialBoundSubject,
  engineSessionSubject: _engineSessionSubject,
}) {
  return credentialBoundSubject;
}
