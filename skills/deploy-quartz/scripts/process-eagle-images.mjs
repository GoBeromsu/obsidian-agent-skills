#!/usr/bin/env node

import fs from 'fs';
import path from 'path';

// Parse command-line arguments
const [stagingDir, eagleLibraryPath, attachmentsDir] = process.argv.slice(2);

if (!stagingDir || !eagleLibraryPath || !attachmentsDir) {
  console.error('Usage: process-eagle-images.mjs <staging-dir> <eagle-library-path> <attachments-dir>');
  process.exit(1);
}

if (!fs.existsSync(attachmentsDir)) {
  fs.mkdirSync(attachmentsDir, { recursive: true });
}

/**
 * Recursively find all markdown files in a directory.
 */
function findMarkdownFiles(dir) {
  const files = [];
  const items = fs.readdirSync(dir, { withFileTypes: true });

  for (const item of items) {
    const fullPath = path.join(dir, item.name);
    if (item.isDirectory()) {
      files.push(...findMarkdownFiles(fullPath));
    } else if (item.isFile() && item.name.endsWith('.md')) {
      files.push(fullPath);
    }
  }

  return files;
}

/**
 * Extract Eagle image references from markdown content.
 * Matches: ![alt](file:///...Ataraxia.library/images/...)
 * Returns the full match, alt text, and absolute file path.
 */
function findEagleImages(content) {
  const eaglePattern = /!\[([^\]]*)\]\((file:\/\/\/[^)]*Ataraxia\.library\/images\/[^)]+)\)/g;
  const matches = [];

  for (const match of content.matchAll(eaglePattern)) {
    const fileUrl = match[2];
    const filePath = decodeURIComponent(fileUrl.replace('file://', ''));

    matches.push({
      fullMatch: match[0],
      altText: match[1],
      imagePath: filePath,
    });
  }

  return matches;
}

/**
 * Generate a descriptive filename from alt text or Eagle ID.
 */
function generateDescriptiveFilename(altText, imagePath, index) {
  const ext = path.extname(imagePath);

  if (altText && altText.trim()) {
    const slug = altText.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
    return `${slug}${ext}`;
  }

  const eagleId = imagePath.match(/images\/([^/]+)\.info/)?.[1];
  return `eagle-${eagleId || index}${ext}`;
}

/**
 * Copy an Eagle image to the attachments directory.
 * Returns the final filename on success, or null if the source is missing.
 */
function copyEagleImage(imagePath, newFilename) {
  if (!fs.existsSync(imagePath)) {
    console.warn(`  Warning: Source image not found: ${imagePath}`);
    return null;
  }

  // Deduplicate filenames to avoid overwrites
  let finalPath = path.join(attachmentsDir, newFilename);
  let counter = 1;
  while (fs.existsSync(finalPath)) {
    const ext = path.extname(newFilename);
    const base = path.basename(newFilename, ext);
    finalPath = path.join(attachmentsDir, `${base}-${counter}${ext}`);
    counter++;
  }

  try {
    fs.copyFileSync(imagePath, finalPath);
    const finalFilename = path.basename(finalPath);
    console.log(`  Copied: ${finalFilename}`);
    return finalFilename;
  } catch (error) {
    console.error(`  Failed to copy ${imagePath}: ${error.message}`);
    return null;
  }
}

/**
 * Process a single markdown file: find Eagle images, copy them,
 * and rewrite the markdown references to point to /_attachments/.
 */
function processMarkdownFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const eagleImages = findEagleImages(content);

  if (eagleImages.length === 0) {
    return false;
  }

  console.log(`\nProcessing: ${path.relative(stagingDir, filePath)}`);
  console.log(`  Found ${eagleImages.length} Eagle image(s)`);

  let newContent = content;
  let changesApplied = false;

  for (const [index, image] of eagleImages.entries()) {
    const newFilename = generateDescriptiveFilename(image.altText, image.imagePath, index);
    const copiedFilename = copyEagleImage(image.imagePath, newFilename);

    if (copiedFilename) {
      const newMarkdown = `![${image.altText}](/_attachments/${copiedFilename})`;
      newContent = newContent.replace(image.fullMatch, newMarkdown);
      changesApplied = true;
    }
  }

  if (changesApplied) {
    fs.writeFileSync(filePath, newContent, 'utf-8');
    console.log(`  Updated markdown file`);
    return true;
  }

  return false;
}

/**
 * Main: scan all markdown files in staging and process Eagle images.
 */
function main() {
  console.log('Scanning for Eagle image paths in staging...\n');

  const markdownFiles = findMarkdownFiles(stagingDir);
  let filesProcessed = 0;

  for (const file of markdownFiles) {
    if (processMarkdownFile(file)) {
      filesProcessed++;
    }
  }

  console.log(`\nEagle processing complete. Processed ${filesProcessed} file(s)`);

  if (filesProcessed === 0) {
    console.log('  No Eagle images found in staging.');
  }
}

main();
