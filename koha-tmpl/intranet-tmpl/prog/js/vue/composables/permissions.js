const isUserPermittedHandler = (operation, permissions, store) => {
    return true; // TODO - new permissions need creating and testing
    const userPermissions = permissions ? permissions : store.userPermissions;
    if (!operation) return true;
    if (!userPermissions) return false;

    return (
        userPermissions.hasOwnProperty(operation) && userPermissions[operation]
    );
};

export const permissionsActions = store => {
    return {
        isUserPermitted(operation, permissions) {
            return isUserPermittedHandler(operation, permissions, store);
        },
    };
};
