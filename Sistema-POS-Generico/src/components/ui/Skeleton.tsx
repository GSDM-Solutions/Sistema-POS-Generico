interface SkeletonProps {
    className?: string;
    variant?: 'text' | 'circular' | 'rectangular';
    width?: string;
    height?: string;
    count?: number;
}

export function Skeleton({
    className = '',
    variant = 'text',
    width,
    height,
    count = 1
}: SkeletonProps) {
    const baseClasses = 'animate-pulse bg-gradient-to-r from-gray-200 via-gray-100 to-gray-200 bg-[length:200%_100%]';

    const variantClasses = {
        text: 'h-4 rounded',
        circular: 'rounded-full',
        rectangular: 'rounded-lg'
    };

    const style = {
        width: width || (variant === 'circular' ? '40px' : '100%'),
        height: height || (variant === 'circular' ? '40px' : undefined)
    };

    if (count > 1) {
        return (
            <div className="space-y-2">
                {Array.from({ length: count }).map((_, i) => (
                    <div
                        key={i}
                        className={`${baseClasses} ${variantClasses[variant]} ${className}`}
                        style={style}
                    />
                ))}
            </div>
        );
    }

    return (
        <div
            className={`${baseClasses} ${variantClasses[variant]} ${className}`}
            style={style}
        />
    );
}

// Skeleton presets para casos comunes
export function ProductCardSkeleton() {
    return (
        <div className="bg-white p-4 rounded-xl border-2 border-gray-100 space-y-3">
            <div className="flex justify-between items-start">
                <Skeleton width="60%" height="20px" />
                <Skeleton width="80px" height="24px" />
            </div>
            <div className="flex items-center gap-2">
                <Skeleton variant="circular" width="32px" height="32px" />
                <Skeleton width="40%" height="16px" />
            </div>
            <div className="flex justify-between items-center">
                <Skeleton width="120px" height="32px" />
                <Skeleton width="80px" height="32px" />
            </div>
        </div>
    );
}

export function TableRowSkeleton({ columns = 4 }: { columns?: number }) {
    return (
        <tr className="border-b border-gray-100">
            {Array.from({ length: columns }).map((_, i) => (
                <td key={i} className="p-3">
                    <Skeleton height="16px" />
                </td>
            ))}
        </tr>
    );
}

export function ListItemSkeleton() {
    return (
        <div className="flex items-center gap-3 p-3 bg-gray-50 rounded-lg">
            <Skeleton variant="circular" width="48px" height="48px" />
            <div className="flex-1 space-y-2">
                <Skeleton width="70%" height="18px" />
                <Skeleton width="40%" height="14px" />
            </div>
            <Skeleton width="80px" height="32px" />
        </div>
    );
}
