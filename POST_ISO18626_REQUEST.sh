curl  -X POST   http://localhost:8081/api/v1/public/ill/iso18626   -H 'Content-Type: application/xml'   -u koha:koha   -d '<request xmlns="http://example.com/ill/request">
        <header>
          <requestingAgencyRequestId>MYREQUESTID</requestingAgencyRequestId>
          <timestamp>2023-03-15 14:30:00</timestamp>
          <requestingAgencyId>
            <agencyIdType>ISIL</agencyIdType>
            <agencyIdValue>req_agency_value</agencyIdValue>
          </requestingAgencyId>
          <requestingAgencyAuthentication>
	    <accountId>kohaid</accountId>
	    <securityCode>kohacode</securityCode>
          </requestingAgencyAuthentication>
        </header>
        <bibliographicInfo>
          <bibliographicItemId>
            <bibliographicItemIdentifierCode>DOI</bibliographicItemIdentifierCode>
            <bibliographicItemIdentifier>10.0004/123123</bibliographicItemIdentifier>
          </bibliographicItemId>
          <bibliographicItemId>
            <bibliographicItemIdentifierCode>DOI</bibliographicItemIdentifierCode>
            <bibliographicItemIdentifier>second DOI</bibliographicItemIdentifier>
          </bibliographicItemId>
          <bibliographicRecordId>
            <bibliographicRecordIdentifier>123</bibliographicRecordIdentifier>
            <bibliographicRecordIdentifierCode>PMID</bibliographicRecordIdentifierCode>
          </bibliographicRecordId>
          <title>This is an optional title</title>
          <author>This is an optional author</author>
          <edition>This is an optional edition</edition>
          <issue>This is an optional edition</issue>
          <sponsor>This is an optional sponsor</sponsor>
        </bibliographicInfo>
        <publicationInfo>
          <publicationType>Article</publicationType>
        </publicationInfo>
        <serviceInfo>
          <serviceType>Loan</serviceType>
        </serviceInfo>
      </request>'
