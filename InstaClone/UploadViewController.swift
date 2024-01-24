//
//  UploadViewController.swift
//  InstaClone
//
//  Created by Test on 12.11.23.
//

import UIKit
import PhotosUI
import FirebaseCore
import FirebaseStorage
import FirebaseFirestoreInternal
import FirebaseAuth

class UploadViewController: UIViewController, PHPickerViewControllerDelegate, UINavigationControllerDelegate {
    var selection = [String: PHPickerResult]()
    var selectedAssetIdentifiers = [String]()
    var selectedAssetIdentifierIterator: IndexingIterator<[String]>?
    var currentAssetIdentifier: String?
    
    var chosenPainting = ""
    var chosenPaintingID: UUID?
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var commentText: UITextField!
    @IBOutlet weak var uploadButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        imageView.isUserInteractionEnabled = true
        let imageTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(selectImage))
        imageView.addGestureRecognizer(imageTapRecognizer)
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        let existingSelection = self.selection
        var newSelection = [String: PHPickerResult]()
        for result in results {
            let identifier = result.assetIdentifier!
            newSelection[identifier] = existingSelection[identifier] ?? result
        }
        selection = newSelection
        selectedAssetIdentifiers = results.map(\.assetIdentifier!)
        selectedAssetIdentifierIterator = selectedAssetIdentifiers.makeIterator()
        
        // update the imageView
        guard let assetIdentifier = selectedAssetIdentifierIterator?.next() else {
            return }
        currentAssetIdentifier = assetIdentifier

        let itemProvider = selection[assetIdentifier]!.itemProvider
        
        // if the object selected is loadable, execute
        if itemProvider.canLoadObject(ofClass: UIImage.self) {
            // set the selected image to imageView as a UIImage
            imageView.image = itemProvider as? UIImage
            // dismiss the picker controller view
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func handleCompletion(assetIdentifier: String, object: Any?, error: Error? = nil) {
        guard currentAssetIdentifier == assetIdentifier else { return }
        if let image = object as? UIImage {
            imageView.image = image
        } else if let error = error {
            print("Couldn't display \(assetIdentifier) with error: \(error)")
        } else {
            print("Error")
        }
    }
    
   @objc func selectImage() {
        
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        let myFilter = PHPickerFilter.any(of: [.images]) //only show images
        //apply preferences for PHPicker session
        configuration.filter = myFilter
        configuration.preferredAssetRepresentationMode = .current
        configuration.selectionLimit = 1
        configuration.selection = .ordered
        //launch the session with our configuration options
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        imageView.image = info[.originalImage] as? UIImage
        self.dismiss(animated: true, completion: nil)
    }

    func makeAlert(titleInput: String, messageInput: String) {
        let alert = UIAlertController(title: titleInput, message: messageInput, preferredStyle: UIAlertController.Style.alert)
        let okButton = UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil)
        alert.addAction(okButton)
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func uploadButtonClicked(_ sender: Any) {
        
        
        let storage = Storage.storage()
        let storageReference = storage.reference()
        let mediaFolder = storageReference.child("media")
        
        if let data = imageView.image?.jpegData(compressionQuality: 0.5) {
            
            let uuid = UUID().uuidString
            
            let imageReference = mediaFolder.child("\(uuid).jpg")
            imageReference.putData(data, metadata: nil) { metadata, error in
                if error != nil {
                    self.makeAlert(titleInput: "Error", messageInput: error?.localizedDescription ?? "Error")
                } else {
                    imageReference.downloadURL { url, error in
                        if error == nil {
                            let imageUrl = url?.absoluteString
                        
                            //database
                            let firestoreDatabase = Firestore.firestore()
                            var firestoreReference: DocumentReference? = nil
                            let firestorePost = ["imageUrl" : imageUrl!, "postedBy" : Auth.auth().currentUser!.email!, "postComment" : self.commentText.text!, "date" : FieldValue.serverTimestamp(), "likes" : 0]
                            firestoreReference = firestoreDatabase.collection("Posts").addDocument(data: firestorePost, completion: { error in
                                if error != nil {
                                    self.makeAlert(titleInput: "Error", messageInput: error?.localizedDescription ?? "Error")
                                } else {
                                    self.imageView.image = UIImage(named: "select.png")
                                    self.commentText.text = ""
                                    self.tabBarController?.selectedIndex = 0
                                    
                                }
                            })
                            
                        }
                    }
                }
            }
        }
            
    }
    
}
