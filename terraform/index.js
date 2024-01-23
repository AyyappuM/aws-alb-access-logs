exports.handler = async (event, context) => {
    // Your logic here

    return {
        statusCode: 200,
        body: 'Hello from Lambda!',
        headers: {
            'Content-Type': 'text/plain'
        }
    };
};
