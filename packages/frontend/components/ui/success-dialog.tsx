'use client';

import { useEffect } from "react";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { ExternalLink, RefreshCw, CheckCircle, X } from "lucide-react";

interface SuccessDialogProps {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  message: string;
  transactionHash?: string;
  onRefresh?: () => void;
  networkExplorer?: string;
}

export function SuccessDialog({
  isOpen,
  onClose,
  title,
  message,
  transactionHash,
  onRefresh,
  networkExplorer
}: SuccessDialogProps) {
  
  // Debug log
  console.log('SuccessDialog props:', { title, message, transactionHash, networkExplorer });
  
    // Remove auto-close functionality
  // useEffect(() => {
  //   if (isOpen) {
  //     const timer = setTimeout(() => {
  //       onClose();
  //     }, 5000); // 5 seconds

  //     return () => clearTimeout(timer);
  //   }
  // }, [isOpen, onClose]);
  const handleViewOnExplorer = () => {
    if (transactionHash && networkExplorer) {
      const explorerUrl = `${networkExplorer}/tx/${transactionHash}`;
      console.log('Opening explorer:', explorerUrl);
      window.open(explorerUrl, '_blank');
    }
  };

  const handleRefresh = () => {
    if (onRefresh) {
      onRefresh();
    }
    onClose();
  };

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2 text-green-700">
            <CheckCircle className="h-5 w-5" />
            {title}
          </DialogTitle>
        </DialogHeader>
        
        <div className="space-y-4">
          <p className="text-sm text-gray-600">
            {message}
          </p>
          
          {/* Action Buttons */}
          <div className="flex flex-col sm:flex-row gap-2">
            {transactionHash && (
              <Button
                variant="outline"
                onClick={handleViewOnExplorer}
                className="flex-1"
              >
                <ExternalLink className="h-4 w-4 mr-2" />
                View on Explorer
              </Button>
            )}
            
            <Button
              variant="outline"
              onClick={onClose}
              className="flex-1"
            >
              <X className="h-4 w-4 mr-2" />
              Close
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
