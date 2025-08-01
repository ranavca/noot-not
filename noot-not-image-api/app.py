from flask import Flask, request, jsonify, send_from_directory
import os
import requests
from dotenv import load_dotenv
import logging
from image_generator import ImageGeneratorService

# Load environment variables
load_dotenv()

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration
config = {
    'IMAGE_WIDTH': int(os.getenv('IMAGE_WIDTH', 1920)),
    'IMAGE_HEIGHT': int(os.getenv('IMAGE_HEIGHT', 1920)),
    'FONT_SIZE': int(os.getenv('FONT_SIZE', 84)),
    'LINE_HEIGHT': int(os.getenv('LINE_HEIGHT', 110)),
    'MAX_LINES_PER_IMAGE': int(os.getenv('MAX_LINES_PER_IMAGE', 15)),
    'TEXT_MARGIN': int(os.getenv('TEXT_MARGIN', 100)),
    'FONTS_DIR': os.getenv('FONTS_DIR', './assets/fonts'),
    'IMAGES_DIR': os.getenv('IMAGES_DIR', './assets/images'),
    'BACKGROUND_DIR': os.getenv('BACKGROUND_DIR', './assets/backgrounds'),
}

# Initialize image generator
image_generator = ImageGeneratorService(config)

# PHP API configuration
PHP_API_BASE_URL = os.getenv('PHP_API_BASE_URL', 'http://localhost:8000')

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'noot-not-image-api',
        'version': '1.0.0'
    })

@app.route('/generate-images', methods=['POST'])
def generate_images():
    """Generate images for a confession"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No JSON data provided'}), 400
            
        confession_id = data.get('confession_id')
        content = data.get('content')
        
        if not confession_id or not content:
            return jsonify({'error': 'confession_id and content are required'}), 400
        
        logger.info(f"Generating images for confession {confession_id}")
        
        # Generate images
        image_urls = image_generator.generate_confession_images(confession_id, content)
        
        logger.info(f"Generated {len(image_urls)} images for confession {confession_id}")
        
        # Return the image URLs
        response = {
            'success': True,
            'confession_id': confession_id,
            'image_urls': image_urls,
            'total_images': len(image_urls)
        }
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Error generating images: {str(e)}")
        return jsonify({
            'error': 'Failed to generate images',
            'message': str(e)
        }), 500

@app.route('/images/<filename>')
def serve_image(filename):
    """Serve generated images"""
    try:
        return send_from_directory(config['IMAGES_DIR'], filename)
    except FileNotFoundError:
        return jsonify({'error': 'Image not found'}), 404

@app.route('/webhook/confession-created', methods=['POST'])
def confession_created_webhook():
    """Webhook endpoint for when a confession is created"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No JSON data provided'}), 400
        
        confession_id = data.get('confession_id')
        content = data.get('content')
        
        if not confession_id or not content:
            return jsonify({'error': 'confession_id and content are required'}), 400
        
        logger.info(f"Received webhook for confession {confession_id}")
        
        # Generate images
        image_urls = image_generator.generate_confession_images(confession_id, content)
        
        # Send the image URLs back to the PHP API
        update_payload = {
            'confession_id': confession_id,
            'image_urls': image_urls
        }
        
        try:
            response = requests.post(
                f"{PHP_API_BASE_URL}/api/confessions/{confession_id}/update-images",
                json=update_payload,
                timeout=10
            )
            
            if response.status_code == 200:
                logger.info(f"Successfully updated confession {confession_id} with images")
            else:
                logger.warning(f"Failed to update confession {confession_id}: {response.status_code}")
                
        except requests.RequestException as e:
            logger.error(f"Failed to send images back to PHP API: {str(e)}")
        
        return jsonify({
            'success': True,
            'confession_id': confession_id,
            'image_urls': image_urls,
            'total_images': len(image_urls)
        })
        
    except Exception as e:
        logger.error(f"Error in webhook: {str(e)}")
        return jsonify({
            'error': 'Webhook processing failed',
            'message': str(e)
        }), 500

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    # Ensure directories exist
    os.makedirs(config['IMAGES_DIR'], exist_ok=True)
    
    # Start the server
    host = os.getenv('HOST', '0.0.0.0')
    port = int(os.getenv('PORT', 9999))
    debug = os.getenv('DEBUG', 'True').lower() == 'true'
    
    logger.info(f"Starting Noot Not Image API on {host}:{port}")
    logger.info(f"Images will be served from: {config['IMAGES_DIR']}")
    logger.info(f"PHP API URL: {PHP_API_BASE_URL}")
    
    app.run(host=host, port=port, debug=debug)
