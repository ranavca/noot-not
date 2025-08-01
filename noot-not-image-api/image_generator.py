from PIL import Image, ImageDraw, ImageFont
import os
import re
import math
from typing import List, Tuple, Dict, Any
import json

class ImageGeneratorService:
    def __init__(self, config: Dict[str, Any]):
        self.image_width = config.get('IMAGE_WIDTH', 1920)
        self.image_height = config.get('IMAGE_HEIGHT', 1920)
        self.font_size = config.get('FONT_SIZE', 84)
        self.line_height = config.get('LINE_HEIGHT', 110)
        self.max_lines_per_image = config.get('MAX_LINES_PER_IMAGE', 15)
        self.text_margin = config.get('TEXT_MARGIN', 100)
        self.max_text_width = self.image_width - (self.text_margin * 2)
        
        # Font paths
        self.fonts_dir = config.get('FONTS_DIR', './assets/fonts')
        self.font_path = os.path.join(self.fonts_dir, 'noto-sans.ttf')
        self.emoji_font_path = os.path.join(self.fonts_dir, 'noto-emoji-bw.ttf')
        
        # Directories
        self.images_dir = config.get('IMAGES_DIR', './assets/images')
        self.backgrounds_dir = config.get('BACKGROUND_DIR', './assets/backgrounds')
        
        # Create directories if they don't exist
        os.makedirs(self.images_dir, exist_ok=True)
        os.makedirs(self.backgrounds_dir, exist_ok=True)
        
        # Load fonts
        self.load_fonts()

    def load_fonts(self):
        """Load the fonts or set fallback"""
        try:
            if os.path.exists(self.font_path):
                self.font = ImageFont.truetype(self.font_path, self.font_size)
            else:
                self.font = ImageFont.load_default()
                
            # Try to load emoji font, but prepare for fallback
            self.emoji_font_available = False
            if os.path.exists(self.emoji_font_path):
                try:
                    self.emoji_font = ImageFont.truetype(self.emoji_font_path, self.font_size)
                    # Test if emoji font can actually render emojis
                    test_bbox = self.emoji_font.getbbox('😊')
                    if test_bbox[2] - test_bbox[0] > 0:
                        self.emoji_font_available = True
                        print("✅ Emoji font loaded and working")
                    else:
                        print("⚠️  Emoji font loaded but cannot render emojis properly")
                        self.emoji_font = self.font
                except Exception as e:
                    print(f"⚠️  Emoji font failed to load: {e}")
                    self.emoji_font = self.font
            else:
                print("⚠️  Emoji font file not found, using text fallbacks")
                self.emoji_font = self.font
                
            # ID font (bigger - about 75% of main font size)
            id_font_size = int(self.font_size)  # About 63px if font_size is 84px
            if os.path.exists(self.font_path):
                self.id_font = ImageFont.truetype(self.font_path, id_font_size)
            else:
                self.id_font = ImageFont.load_default()
                
        except Exception as e:
            print(f"Error loading fonts: {e}")
            self.font = ImageFont.load_default()
            self.emoji_font = ImageFont.load_default()
            self.id_font = ImageFont.load_default()
            self.emoji_font_available = False

    def contains_emoji(self, text: str) -> bool:
        """Check if text contains emojis"""
        emoji_pattern = re.compile(
            "[\U0001F600-\U0001F64F"  # emoticons
            "\U0001F300-\U0001F5FF"  # symbols & pictographs
            "\U0001F680-\U0001F6FF"  # transport & map symbols
            "\U0001F1E0-\U0001F1FF"  # flags (iOS)
            "\U00002600-\U000026FF"  # miscellaneous symbols
            "\U00002700-\U000027BF"  # dingbats
            "\U0001F900-\U0001F9FF"  # supplemental symbols and pictographs
            "\U0001FA70-\U0001FAFF"  # symbols and pictographs extended-A
            "]+", 
            flags=re.UNICODE
        )
        return bool(emoji_pattern.search(text))

    def split_text_and_emojis(self, text: str) -> List[Tuple[str, bool]]:
        """Split text into segments, marking which are emojis and which are regular text"""
        emoji_pattern = re.compile(
            "([\U0001F600-\U0001F64F"  # emoticons
            "\U0001F300-\U0001F5FF"  # symbols & pictographs
            "\U0001F680-\U0001F6FF"  # transport & map symbols
            "\U0001F1E0-\U0001F1FF"  # flags (iOS)
            "\U00002600-\U000026FF"  # miscellaneous symbols
            "\U00002700-\U000027BF"  # dingbats
            "\U0001F900-\U0001F9FF"  # supplemental symbols and pictographs
            "\U0001FA70-\U0001FAFF"  # symbols and pictographs extended-A
            "]+)", 
            flags=re.UNICODE
        )
        
        segments = []
        parts = emoji_pattern.split(text)
        
        for part in parts:
            if part:  # Skip empty strings
                is_emoji = bool(emoji_pattern.match(part))
                segments.append((part, is_emoji))
        
        return segments

    def convert_emojis_to_text(self, text: str) -> str:
        """Convert emojis to text representations as fallback"""
        emoji_map = {
            # Caras y emociones
            '😀': ':D', '😁': ':D', '😂': 'XD', '🤣': 'XD', '😃': ':D',
            '😄': ':D', '😅': ':)', '😆': 'XD', '😊': ':)', '😇': ':)',
            '🙂': ':)', '🙃': ':)', '😉': ';)', '😌': ':)', '😍': '<3',
            '🥰': '<3', '😘': ':*', '😗': ':*', '😙': ':*', '😚': ':*',
            '😋': ':P', '😛': ':P', '😝': 'XP', '😜': ';P', '🤪': 'XP',
            '🤨': ':/', '🧐': '(monocle)', '🤓': '(nerd)', '😎': 'B)',
            '🤩': '*_*', '🥳': '(party)',
            
            # Emociones negativas
            '😞': ':(', '😒': ':|', '😔': ':(', '😟': ':(', '😕': ':(',
            '🙁': ':(', '☹️': ':(', '😣': '>:(', '😖': '>:(', '😫': 'X(',
            '😩': ':(', '🥺': ':(', '😢': 'T_T', '😭': 'T_T', '😤': '>:(',
            '😠': '>:(', '😡': '>:(', '🤬': '****', '🤯': '(mind blown)',
            '😳': 'O_O', '🥵': '(hot)', '🥶': '(cold)', '😱': ':O',
            '😨': 'D:', '😰': 'D:', '😥': ':(', '😓': ':-/',
            
            # Gestos y manos
            '👍': '(thumbs up)', '👎': '(thumbs down)', '👌': '(OK)',
            '✌️': '(peace)', '🤞': '(fingers crossed)', '🤟': '(love)',
            '🤘': '(rock)', '🤙': '(call me)', '👈': '(point left)',
            '👉': '(point right)', '👆': '(point up)', '👇': '(point down)',
            '☝️': '(index up)', '✋': '(hand)', '🤚': '(hand)', '🖐️': '(hand)',
            '🖖': '(vulcan)', '👋': '(wave)', '🤝': '(handshake)',
            '🙏': '(pray)', '✍️': '(write)', '💪': '(strong)',
            
            # Corazones y amor
            '❤️': '<3', '🧡': '<3', '💛': '<3', '💚': '<3', '💙': '<3',
            '💜': '<3', '🖤': '</3', '🤍': '<3', '🤎': '<3', '💔': '</3',
            '❣️': '<3', '💕': '<3', '💞': '<3', '💓': '<3', '💗': '<3',
            '💖': '<3', '💘': '<3', '💝': '<3', '💟': '<3',
            
            # Objetos y símbolos
            '🔥': '(fire)', '⭐': '(star)', '🌟': '(star)', '✨': '(sparkles)',
            '💫': '(dizzy)', '💥': '(boom)', '💯': '(100)', '💢': '(anger)',
            '💦': '(sweat)', '💨': '(dash)', '🕳️': '(hole)', '💤': '(sleep)',
            '🎉': '(party)', '🎊': '(confetti)', '🎈': '(balloon)',
            '🎁': '(gift)', '🎂': '(cake)', '🍰': '(cake)', '🎵': '(music)',
            '🎶': '(music)', '🎯': '(target)', '🏆': '(trophy)',
            '🥇': '(gold)', '🥈': '(silver)', '🥉': '(bronze)',
            '🏅': '(medal)', '🎖️': '(medal)',
            
            # Transporte y tecnología
            '🚀': '(rocket)', '✈️': '(plane)', '🚗': '(car)', '🏠': '(home)',
            '🏫': '(school)', '🏢': '(office)', '🏥': '(hospital)',
            '🏪': '(store)', '🎬': '(movie)', '📱': '(phone)',
            '💻': '(computer)', '📷': '(camera)', '📺': '(TV)',
            '⏰': '(clock)', '📅': '(calendar)', '📚': '(books)',
            '✏️': '(pencil)', '📝': '(memo)', '📄': '(page)', '📋': '(clipboard)',
            
            # Naturaleza
            '🌞': '(sun)', '🌙': '(moon)', '🌈': '(rainbow)', '☀️': '(sun)',
            '⛅': '(cloud)', '☁️': '(cloud)', '🌧️': '(rain)',
            '⛈️': '(storm)', '🌩️': '(lightning)', '❄️': '(snow)',
            '🌨️': '(snow)', '🌊': '(wave)', '🌳': '(tree)',
            '🌸': '(flower)', '🌺': '(flower)', '🌻': '(flower)',
            '🌹': '(rose)', '🌷': '(tulip)',
            
            # Comida y bebida
            '🍕': '(pizza)', '🍔': '(burger)', '🍟': '(fries)',
            '🌭': '(hotdog)', '🥪': '(sandwich)', '🌮': '(taco)',
            '🌯': '(burrito)', '🍣': '(sushi)', '🍜': '(ramen)',
            '🍝': '(pasta)', '🍪': '(cookie)', '🍫': '(chocolate)',
            '🍯': '(honey)', '☕': '(coffee)', '🍵': '(tea)',
            '🥤': '(drink)', '🍺': '(beer)', '🍷': '(wine)',
        }
        
        result = text
        for emoji, text_replacement in emoji_map.items():
            result = result.replace(emoji, text_replacement)
        
        return result

    def get_text_width(self, text: str, font: ImageFont.ImageFont) -> int:
        """Get the width of text with given font"""
        try:
            bbox = font.getbbox(text)
            return bbox[2] - bbox[0]
        except:
            # Fallback estimation
            return len(text) * (self.font_size // 2)

    def get_mixed_text_width(self, text: str) -> int:
        """Get the width of text that may contain both regular text and emojis"""
        segments = self.split_text_and_emojis(text)
        total_width = 0
        
        for segment, is_emoji in segments:
            if is_emoji:
                total_width += self.get_text_width(segment, self.emoji_font)
            else:
                total_width += self.get_text_width(segment, self.font)
        
        return total_width

    def wrap_text(self, text: str) -> List[str]:
        """Wrap text into lines that fit within the image width"""
        words = text.split(' ')
        lines = []
        current_line = ''
        max_width = self.max_text_width - 100  # Leave margin
        
        for word in words:
            test_line = current_line + ' ' + word if current_line else word
            
            if self.get_mixed_text_width(test_line) <= max_width:
                current_line = test_line
            else:
                if current_line:
                    lines.append(current_line)
                current_line = word
                
                # If single word is too long, force break it
                if self.get_mixed_text_width(current_line) > max_width:
                    lines.append(current_line)
                    current_line = ''
        
        if current_line:
            lines.append(current_line)
        
        return lines

    def create_gradient_background(self) -> Image.Image:
        """Create a background image from assets/backgrounds/bg.png"""
        bg_path = os.path.join(self.backgrounds_dir, 'bg.png')
        
        try:
            # Load the background image
            background = Image.open(bg_path)
            
            # Convert to RGB if necessary (in case it's RGBA or other format)
            if background.mode != 'RGB':
                background = background.convert('RGB')
            
            # Resize to match our target dimensions if needed
            if background.size != (self.image_width, self.image_height):
                background = background.resize((self.image_width, self.image_height), Image.Resampling.LANCZOS)
            
            return background
            
        except Exception as e:
            print(f"Error loading background image from {bg_path}: {e}")
            print("Falling back to gradient background")
            
            # Fallback to gradient if image loading fails
            image = Image.new('RGB', (self.image_width, self.image_height))
            
            for y in range(self.image_height):
                ratio = y / self.image_height
                
                # Purple to blue gradient
                r = int(107 + (67 - 107) * ratio)  # 107 -> 67
                g = int(114 + (56 - 114) * ratio)  # 114 -> 56
                b = int(224 + (184 - 224) * ratio)  # 224 -> 184
                
                for x in range(self.image_width):
                    image.putpixel((x, y), (r, g, b))
            
            return image

    def add_text_with_effects(self, draw: ImageDraw.Draw, text: str, x: int, y: int, 
                            font: ImageFont.ImageFont, text_color: Tuple[int, int, int] = (0, 0, 0),
                            shadow_color: Tuple[int, int, int] = (150, 150, 150),
                            outline_color: Tuple[int, int, int] = (128, 128, 128)):
        """Add text with shadow and outline effects"""
        
        # Add shadow (offset by 4 pixels)
        draw.text((x + 4, y + 4), text, font=font, fill=shadow_color)
        
        # Add outline by drawing text in multiple directions
        for ox in range(-2, 3):
            for oy in range(-2, 3):
                if ox != 0 or oy != 0:
                    draw.text((x + ox, y + oy), text, font=font, fill=outline_color)
        
        # Add main text
        draw.text((x, y), text, font=font, fill=text_color)

    def add_mixed_text_with_effects(self, draw: ImageDraw.Draw, text: str, x: int, y: int,
                                  text_color: Tuple[int, int, int] = (0, 0, 0),
                                  shadow_color: Tuple[int, int, int] = (150, 150, 150),
                                  outline_color: Tuple[int, int, int] = (128, 128, 128)):
        """Add text that may contain emojis with shadow and outline effects"""
        segments = self.split_text_and_emojis(text)
        current_x = x
        
        for segment, is_emoji in segments:
            if is_emoji:
                try:
                    # Try to render with emoji font first
                    bbox = self.emoji_font.getbbox(segment)
                    emoji_width = bbox[2] - bbox[0]
                    
                    if emoji_width > 0:  # Emoji font can render this
                        # For emojis, we'll render them larger and without heavy effects
                        # to preserve readability
                        
                        # Light shadow for emoji
                        draw.text((current_x + 2, y + 2), segment, font=self.emoji_font, fill=(200, 200, 200))
                        
                        # Main emoji (slightly larger size for better visibility)
                        draw.text((current_x, y), segment, font=self.emoji_font, fill=text_color)
                        current_x += emoji_width
                    else:
                        # Fallback to text conversion
                        fallback_text = self.convert_emojis_to_text(segment)
                        self.add_text_with_effects(draw, fallback_text, current_x, y, self.font, 
                                                 text_color, shadow_color, outline_color)
                        current_x += self.get_text_width(fallback_text, self.font)
                        
                except Exception as e:
                    # Fallback to text conversion
                    print(f"Emoji rendering failed for '{segment}': {e}")
                    fallback_text = self.convert_emojis_to_text(segment)
                    self.add_text_with_effects(draw, fallback_text, current_x, y, self.font, 
                                             text_color, shadow_color, outline_color)
                    current_x += self.get_text_width(fallback_text, self.font)
            else:
                # Regular text
                self.add_text_with_effects(draw, segment, current_x, y, self.font, 
                                         text_color, shadow_color, outline_color)
                current_x += self.get_text_width(segment, self.font)

    def generate_confession_images(self, confession_id: int, content: str) -> List[str]:
        """Generate confession images and return list of image URLs"""
        lines = self.wrap_text(content)
        pages = [lines[i:i + self.max_lines_per_image] for i in range(0, len(lines), self.max_lines_per_image)]
        
        image_urls = []
        
        for page_index, page_lines in enumerate(pages):
            page_number = page_index + 1
            filename = f"{confession_id}-{page_number}.png" if len(pages) > 1 else f"{confession_id}.png"
            image_path = os.path.join(self.images_dir, filename)
            
            self.create_confession_image(page_lines, confession_id, page_number, len(pages), image_path)
            
            # Return relative URL path
            image_urls.append(f"/images/{filename}")
        
        return image_urls

    def create_confession_image(self, lines: List[str], confession_id: int, 
                              page_number: int, total_pages: int, output_path: str):
        """Create a single confession image"""
        
        # Create background
        image = self.create_gradient_background()
        draw = ImageDraw.Draw(image)
        
        # Calculate starting Y position to center text vertically
        total_text_height = len(lines) * self.line_height
        start_y = (self.image_height - total_text_height) // 2
        
        # Add text lines centered horizontally
        for index, line in enumerate(lines):
            y = start_y + (index * self.line_height)
            
            # Center the text horizontally (accounting for mixed content)
            text_width = self.get_mixed_text_width(line)
            x = (self.image_width - text_width) // 2
            
            # Add text with effects (handles both emojis and regular text)
            self.add_mixed_text_with_effects(draw, line, x, y)
        
        # Add confession ID in top right corner
        id_text = f"{confession_id}-{page_number}" if total_pages > 1 else str(confession_id)
        self.add_id_text(draw, id_text)
        
        # Save image
        image.save(output_path, 'PNG', quality=95)

    def add_id_text(self, draw: ImageDraw.Draw, id_text: str):
        """Add ID text in top right corner"""
        margin = 150
        
        # Get text dimensions
        text_width = self.get_text_width(id_text, self.id_font)
        x = self.image_width - text_width - margin
        y = margin
        
        # Add ID text with effects
        self.add_text_with_effects(draw, id_text, x, y, self.id_font)
