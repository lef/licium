SELECT request.case_id,
       'rejected',
       CASE
           WHEN request.login_identifier = '' THEN 'malformed_request'
           WHEN credential.login_identifier IS NULL THEN 'unknown_login'
           WHEN credential.synthetic_proof != request.synthetic_proof
               THEN 'invalid_proof'
           ELSE 'invalid_fixture'
       END
FROM authentication_request AS request
LEFT JOIN credential
  ON credential.login_identifier = request.login_identifier
WHERE request.case_id = @case_id
  AND (
      request.login_identifier = ''
      OR credential.login_identifier IS NULL
      OR credential.synthetic_proof != request.synthetic_proof
  );
