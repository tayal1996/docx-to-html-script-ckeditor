const fs = require( 'fs' );
const jwt = require( 'jsonwebtoken' );
const axios = require( 'axios' );
const FormData = require( 'form-data' );
const path = require('path');
// place ck editor keys below, these are just sample keys here
const accessKey = 'TkNeXsJwdprluTsdlrelTl8Y1IGdK9iaZXCV0ti1L2lUYb5BDKK23A3d3Jsd'; 
const environmentId = 'L5MNy2xdbI3BRqi9TLJF';

const token = jwt.sign( { aud: environmentId }, accessKey, { algorithm: 'HS256' } );

const config = {
    headers: {
        'Authorization': token
    }
};

const conversionConfig = {
    default_styles: true,
    collaboration_features: {
        user_id: 'example_user_id',
        comments: true,
        track_changes: false
    }
};

docx_file = process.argv[2]
const docx_file_path = path.resolve("public", "uploads", "gp_doc", docx_file);
const html_file_path = path.resolve("public", "uploads", "gp_doc", `${docx_file.split('.')[0]}.html`);

const file = fs.readFileSync( docx_file_path );

const formData = new FormData();

formData.append( 'config', JSON.stringify( conversionConfig ));
// The file needs to be added as the last property to the form data.
formData.append( 'file', file, 'file.docx' );

axios.post( 'https://docx-converter.cke-cs.com/v2/convert/docx-html', formData, config )
    .then( response => {
        fs.writeFileSync(html_file_path, response.data.html);
        console.log( 'Conversion result', response.data.html );
        console.log( 'Conversion result', response.data );
    } ).catch( error => {
        console.log( 'Conversion error', error );
    } );
