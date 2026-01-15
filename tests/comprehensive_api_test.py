#!/usr/bin/env python3
"""
Simple API Test Runner for Photo HQ Backend
Tests basic API endpoint functionality without requiring boto3
"""

import os
import sys
import json
import requests
import time
from typing import Dict

# ANSI color codes
class Colors:
    GREEN = '\033[0;32m'
    RED = '\033[0;31m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    BOLD = '\033[1m'
    NC = '\033[0m'

class SimpleAPITester:
    def __init__(self, api_endpoint: str, access_token: str = None):
        self.api_endpoint = api_endpoint.rstrip('/')
        self.access_token = access_token
        self.tests_passed = 0
        self.tests_failed = 0
        self.photo_ids = []
        
    def log(self, msg: str, color: str = Colors.NC):
        print(f"{color}{msg}{Colors.NC}")
        
    def test_pass(self, name: str, details: str = ""):
        self.tests_passed += 1
        self.log(f"✅ PASS: {name}", Colors.GREEN)
        if details:
            self.log(f"   {details}", Colors.CYAN)
            
    def test_fail(self, name: str, details: str = ""):
        self.tests_failed += 1
        self.log(f"❌ FAIL: {name}", Colors.RED)
        if details:
            self.log(f"   {details}", Colors.YELLOW)
    
    def validate_cors(self, headers: Dict) -> bool:
        """Check for CORS headers"""
        return 'Access-Control-Allow-Origin' in headers
    
    def run_tests(self):
        """Run all tests"""
        self.log("\n" + "="*70, Colors.BOLD)
        self.log("Photo HQ Backend - API Test Suite", Colors.BOLD)
        self.log("="*70 + "\n", Colors.BOLD)
        
        if not self.access_token:
            self.log("WARNING: No ACCESS_TOKEN provided", Colors.YELLOW)
            self.log("Some tests will be skipped\n", Colors.YELLOW)
        
        # Run test suites
        self.test_unauthorized_access()
        
        if self.access_token:
            self.test_photo_upload()
            self.test_photo_listing()
            self.test_photo_retrieval()
            self.test_photo_update()
            self.test_photo_metadata()
            self.test_photo_deletion()
            self.test_cors_headers()
            self.test_error_handling()
        
        # Summary
        self.print_summary()
        return self.tests_failed == 0
    
    def test_unauthorized_access(self):
        """Test that endpoints require authentication"""
        self.log("─"*70, Colors.BLUE)
        self.log("Test Suite: Authorization", Colors.BLUE)
        self.log("─"*70 + "\n", Colors.BLUE)
        
        test_name = "Require Authorization for List Photos"
        try:
            resp = requests.get(f"{self.api_endpoint}/photos")
            if resp.status_code == 401:
                self.test_pass(test_name, "Correctly rejected unauthorized request")
            else:
                self.test_fail(test_name, f"Expected 401, got {resp.status_code}")
        except Exception as e:
            self.test_fail(test_name, str(e))
    
    def test_photo_upload(self):
        """Test photo upload endpoint"""
        self.log("\n" + "─"*70, Colors.BLUE)
        self.log("Test Suite: Photo Upload", Colors.BLUE)
        self.log("─"*70 + "\n", Colors.BLUE)
        
        headers = {
            'Authorization': f'Bearer {self.access_token}',
            'Content-Type': 'application/json'
        }
        
        payload = {
            'filename': 'test.jpg',
            'content_type': 'image/jpeg',
            'file_size': 6 * 1024 * 1024
        }
        
        test_name = "Request Upload Presigned URL"
        try:
            resp = requests.post(f"{self.api_endpoint}/photos/upload", 
                               headers=headers, json=payload)
            if resp.status_code == 200:
                data = resp.json()
                if 'photo_id' in data and 'upload_url' in data:
                    self.photo_ids.append(data['photo_id'])
                    self.test_pass(test_name, f"Photo ID: {data['photo_id'][:16]}...")
                else:
                    self.test_fail(test_name, "Missing photo_id or upload_url")
            else:
                self.test_fail(test_name, f"Status {resp.status_code}")
        except Exception as e:
            self.test_fail(test_name, str(e))
    
    def test_photo_listing(self):
        """Test photo listing"""
        self.log("\n" + "─"*70, Colors.BLUE)
        self.log("Test Suite: Photo Listing", Colors.BLUE)
        self.log("─"*70 + "\n", Colors.BLUE)
        
        headers = {'Authorization': f'Bearer {self.access_token}'}
        
        test_name = "List All Photos"
        try:
            resp = requests.get(f"{self.api_endpoint}/photos", headers=headers)
            if resp.status_code == 200:
                data = resp.json()
                count = data.get('count', 0)
                self.test_pass(test_name, f"Found {count} photos")
            else:
                self.test_fail(test_name, f"Status {resp.status_code}")
        except Exception as e:
            self.test_fail(test_name, str(e))
        
        test_name = "Filter by Original Photos"
        try:
            resp = requests.get(f"{self.api_endpoint}/photos?version_type=original", 
                              headers=headers)
            if resp.status_code == 200:
                self.test_pass(test_name, "Filter working")
            else:
                self.test_fail(test_name, f"Status {resp.status_code}")
        except Exception as e:
            self.test_fail(test_name, str(e))
    
    def test_photo_retrieval(self):
        """Test photo retrieval"""
        if not self.photo_ids:
            self.log("\nSkipping retrieval tests - no photos", Colors.YELLOW)
            return
            
        self.log("\n" + "─"*70, Colors.BLUE)
        self.log("Test Suite: Photo Retrieval", Colors.BLUE)
        self.log("─"*70 + "\n", Colors.BLUE)
        
        headers = {'Authorization': f'Bearer {self.access_token}'}
        photo_id = self.photo_ids[0]
        
        test_name = "Get Photo Download URL"
        try:
            resp = requests.get(f"{self.api_endpoint}/photos/{photo_id}", 
                              headers=headers)
            if resp.status_code == 200:
                data = resp.json()
                if 'download_url' in data:
                    self.test_pass(test_name, "Download URL obtained")
                else:
                    self.test_fail(test_name, "No download_url in response")
            else:
                self.test_fail(test_name, f"Status {resp.status_code}")
        except Exception as e:
            self.test_fail(test_name, str(e))
    
    def test_photo_update(self):
        """Test photo update"""
        if not self.photo_ids:
            self.log("\nSkipping update tests - no photos", Colors.YELLOW)
            return
            
        self.log("\n" + "─"*70, Colors.BLUE)
        self.log("Test Suite: Photo Update", Colors.BLUE)
        self.log("─"*70 + "\n", Colors.BLUE)
        
        headers = {
            'Authorization': f'Bearer {self.access_token}',
            'Content-Type': 'application/json'
        }
        photo_id = self.photo_ids[0]
        
        payload = {
            'filename': 'edited.jpg',
            'content_type': 'image/jpeg',
            'file_size': 7 * 1024 * 1024
        }
        
        test_name = "Request Edit Upload URL"
        try:
            resp = requests.put(f"{self.api_endpoint}/photos/{photo_id}/edit", 
                              headers=headers, json=payload)
            if resp.status_code == 200:
                data = resp.json()
                if 'upload_url' in data:
                    self.test_pass(test_name, "Edit URL obtained")
                else:
                    self.test_fail(test_name, "No upload_url")
            else:
                self.test_fail(test_name, f"Status {resp.status_code}")
        except Exception as e:
            self.test_fail(test_name, str(e))
    
    def test_photo_metadata(self):
        """Test metadata retrieval"""
        if not self.photo_ids:
            self.log("\nSkipping metadata tests - no photos", Colors.YELLOW)
            return
            
        self.log("\n" + "─"*70, Colors.BLUE)
        self.log("Test Suite: Photo Metadata", Colors.BLUE)
        self.log("─"*70 + "\n", Colors.BLUE)
        
        headers = {'Authorization': f'Bearer {self.access_token}'}
        photo_id = self.photo_ids[0]
        
        test_name = "Get Photo Metadata"
        try:
            resp = requests.get(f"{self.api_endpoint}/photos/{photo_id}/metadata", 
                              headers=headers)
            if resp.status_code == 200:
                data = resp.json()
                if 'photo_id' in data and 'original' in data:
                    self.test_pass(test_name, "Metadata retrieved")
                else:
                    self.test_fail(test_name, "Incomplete metadata")
            else:
                self.test_fail(test_name, f"Status {resp.status_code}")
        except Exception as e:
            self.test_fail(test_name, str(e))
    
    def test_photo_deletion(self):
        """Test photo deletion"""
        if not self.photo_ids:
            self.log("\nSkipping deletion tests - no photos", Colors.YELLOW)
            return
            
        self.log("\n" + "─"*70, Colors.BLUE)
        self.log("Test Suite: Photo Deletion", Colors.BLUE)
        self.log("─"*70 + "\n", Colors.BLUE)
        
        headers = {'Authorization': f'Bearer {self.access_token}'}
        photo_id = self.photo_ids.pop(0)
        
        test_name = "Delete Photo"
        try:
            resp = requests.delete(f"{self.api_endpoint}/photos/{photo_id}", 
                                 headers=headers)
            if resp.status_code == 200:
                data = resp.json()
                if 'deleted' in data.get('message', '').lower():
                    self.test_pass(test_name, "Photo deleted")
                else:
                    self.test_fail(test_name, "Unexpected response")
            else:
                self.test_fail(test_name, f"Status {resp.status_code}")
        except Exception as e:
            self.test_fail(test_name, str(e))
        
        test_name = "Verify Deletion (Should 404)"
        try:
            time.sleep(1)
            resp = requests.get(f"{self.api_endpoint}/photos/{photo_id}/metadata", 
                              headers=headers)
            if resp.status_code == 404:
                self.test_pass(test_name, "Photo properly deleted")
            else:
                self.test_fail(test_name, f"Still exists: {resp.status_code}")
        except Exception as e:
            self.test_fail(test_name, str(e))
    
    def test_cors_headers(self):
        """Test CORS configuration"""
        self.log("\n" + "─"*70, Colors.BLUE)
        self.log("Test Suite: CORS Validation", Colors.BLUE)
        self.log("─"*70 + "\n", Colors.BLUE)
        
        headers = {'Authorization': f'Bearer {self.access_token}'}
        
        test_name = "CORS Headers on List Endpoint"
        try:
            resp = requests.get(f"{self.api_endpoint}/photos", headers=headers)
            if self.validate_cors(resp.headers):
                self.test_pass(test_name, "CORS headers present")
            else:
                self.test_fail(test_name, "Missing CORS headers")
        except Exception as e:
            self.test_fail(test_name, str(e))
    
    def test_error_handling(self):
        """Test error handling"""
        self.log("\n" + "─"*70, Colors.BLUE)
        self.log("Test Suite: Error Handling", Colors.BLUE)
        self.log("─"*70 + "\n", Colors.BLUE)
        
        headers = {
            'Authorization': f'Bearer {self.access_token}',
            'Content-Type': 'application/json'
        }
        
        test_name = "Reject Invalid File Size"
        try:
            resp = requests.post(f"{self.api_endpoint}/photos/upload", 
                               headers=headers, 
                               json={'filename': 'tiny.jpg', 
                                    'content_type': 'image/jpeg',
                                    'file_size': 1024})
            if resp.status_code == 400:
                self.test_pass(test_name, "Correctly rejected")
            else:
                self.test_fail(test_name, f"Expected 400, got {resp.status_code}")
        except Exception as e:
            self.test_fail(test_name, str(e))
        
        test_name = "Reject Invalid Content Type"
        try:
            resp = requests.post(f"{self.api_endpoint}/photos/upload", 
                               headers=headers, 
                               json={'filename': 'doc.pdf', 
                                    'content_type': 'application/pdf',
                                    'file_size': 6*1024*1024})
            if resp.status_code == 400:
                self.test_pass(test_name, "Correctly rejected")
            else:
                self.test_fail(test_name, f"Expected 400, got {resp.status_code}")
        except Exception as e:
            self.test_fail(test_name, str(e))
        
        test_name = "404 for Non-Existent Photo"
        try:
            resp = requests.get(
                f"{self.api_endpoint}/photos/00000000-0000-0000-0000-000000000000", 
                headers=headers)
            if resp.status_code == 404:
                self.test_pass(test_name, "Correctly returned 404")
            else:
                self.test_fail(test_name, f"Expected 404, got {resp.status_code}")
        except Exception as e:
            self.test_fail(test_name, str(e))
    
    def print_summary(self):
        """Print test summary"""
        self.log("\n" + "="*70, Colors.BOLD)
        self.log("Test Results Summary", Colors.BOLD)
        self.log("="*70 + "\n", Colors.BOLD)
        
        total = self.tests_passed + self.tests_failed
        rate = (self.tests_passed / total * 100) if total > 0 else 0
        
        self.log(f"Total: {total}", Colors.CYAN)
        self.log(f"Passed: {self.tests_passed}", Colors.GREEN)
        self.log(f"Failed: {self.tests_failed}", Colors.RED)
        self.log(f"Pass Rate: {rate:.1f}%\n", Colors.CYAN)
        
        if self.tests_failed == 0:
            self.log("🎉 All tests passed!", Colors.GREEN)
        else:
            self.log(f"❌ {self.tests_failed} test(s) failed", Colors.RED)

def main():
    api_endpoint = os.getenv('API_ENDPOINT')
    access_token = os.getenv('ACCESS_TOKEN')
    
    if not api_endpoint:
        print(f"{Colors.RED}Error: API_ENDPOINT not set{Colors.NC}")
        print("Set environment variables or create .env file")
        sys.exit(1)
    
    tester = SimpleAPITester(api_endpoint, access_token)
    success = tester.run_tests()
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
