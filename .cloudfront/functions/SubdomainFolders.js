function handler(event) {
    var request = event.request;
    var host = request.headers.host.value;
    var uri = request.uri;

    // Extract subdomain
    var parts = host.split('.');
    var subdomain = (parts.length > 2 && parts[0] !== 'www') ? parts[0] : null;

    // Determine the base directory
    var baseDir = subdomain ? '/' + subdomain : '/production';

    // Check if the request is for a file (has an extension)
    var isFile = uri.split('/').pop().includes('.');

    if (isFile) {
        // If it's a file request, prepend the baseDir if necessary
        if (!uri.startsWith(baseDir + '/')) {
            uri = baseDir + uri;
        }
    } else {
        // For all non-file requests, redirect to the root index.html
        uri = baseDir + '/index.html';
    }

    request.uri = uri;
    return request;
}
