//Approve Employer 
$('#dt-basic-example').on('click', '.js-sweetalert2-approve_employer', function(e) {
    e.preventDefault();
    var button = $(this);
    // prompt("Are you sure")
    Swal.fire({
        title: 'Are sure you?',
        text: "You want to approve!",
        type: "warning",
        showCancelButton: true,
        confirmButtonColor: '#23b05d',
        cancelButtonColor: '#d33',
        confirmButtonText: 'Yes!',
        showLoaderOnConfirm: true
    }).then((result) => {
        if (result.value) {
            $.ajax({
                url: '/Employer/Approve',
                type: 'POST',
                data: { id: button.attr("data-id"), _csrf_token: $("#csrf").val() },
                success: function(result) {
                    console.log(result);
                    if (result.status === 0) {
                        Swal.fire(
                            'Success',
                            result.message,
                            'success'
                        ).then(() => {
                            location.reload(true);
                            spinner.hide();
                        });
                    } else {
                        Swal.fire(
                            'Error',
                            result.message,
                            'error'
                        )
                    }
                },
                error: function(request, msg, error) {
                    Swal.fire(
                        'Oops..',
                        error,
                        'error'
                    )
                },
            });
        } else {
            Swal.fire(
                'error',
                'Operation not performed :)',
                'error'
            )
        }
    });
});


//Approve Employee
$('#dt-basic-example').on('click', '.js-sweetalert2-approve_employee', function(e) {
    e.preventDefault();
    var button = $(this);
    // prompt("Are you sure")
    Swal.fire({
        title: 'Are sure you?',
        text: "You want to activate this record!",
        type: "warning",
        showCancelButton: true,
        confirmButtonColor: '#23b05d',
        cancelButtonColor: '#d33',
        confirmButtonText: 'Yes!',
        showLoaderOnConfirm: true
    }).then((result) => {
        if (result.value) {
            $.ajax({
                url: '/Employee/Approve',
                type: 'POST',
                data: { id: button.attr("data-id"), _csrf_token: $("#_csrf_token").val() },
                success: function(result) {
                    console.log(result);
                    if (result.status === 0) {
                        Swal.fire(
                            'Success',
                            result.message,
                            'success'
                        ).then(() => {
                            location.reload(true);
                            spinner.hide();
                        });
                    } else {
                        Swal.fire(
                            'Error',
                            result.message,
                            'error'
                        )
                    }
                },
                error: function(request, msg, error) {
                    Swal.fire(
                        'Oops..',
                        error,
                        'error'
                    )
                },
            });
        } else {
            Swal.fire(
                'error',
                'Operation not performed :)',
                'error'
            )
        }
    });
});


//Approve Offtaker 
$('#dt-basic-example').on('click', '.js-sweetalert2-approve_offtaker', function(e) {
    e.preventDefault();
    var button = $(this);
    // prompt("Are you sure")
    Swal.fire({
        title: 'Are sure you?',
        text: "You want to approve!",
        type: "warning",
        showCancelButton: true,
        confirmButtonColor: '#23b05d',
        cancelButtonColor: '#d33',
        confirmButtonText: 'Yes!',
        showLoaderOnConfirm: true
    }).then((result) => {
        if (result.value) {
            $.ajax({
                url: '/Offtaker/Approve',
                type: 'POST',
                data: { id: button.attr("data-id"), _csrf_token: $("#csrf").val() },
                success: function(result) {
                    console.log(result);
                    if (result.status === 0) {
                        Swal.fire(
                            'Success',
                            result.message,
                            'success'
                        ).then(() => {
                            location.reload(true);
                            spinner.hide();
                        });
                    } else {
                        Swal.fire(
                            'Error',
                            result.message,
                            'error'
                        )
                    }
                },
                error: function(request, msg, error) {
                    Swal.fire(
                        'Oops..',
                        error,
                        'error'
                    )
                },
            });
        } else {
            Swal.fire(
                'error',
                'Operation not performed :)',
                'error'
            )
        }
    });
});

//Approve Loan Product 
$('#dt-basic-example').on('click', '.js-sweetalert2-approve_loan_products', function(e) {
    e.preventDefault();
    var button = $(this);
    // prompt("Are you sure")
    Swal.fire({
        title: 'Are sure you?',
        text: "You want to approve!",
        type: "warning",
        showCancelButton: true,
        confirmButtonColor: '#23b05d',
        cancelButtonColor: '#d33',
        confirmButtonText: 'Yes!',
        showLoaderOnConfirm: true
    }).then((result) => {
        if (result.value) {
            $.ajax({
                url: '/Approve/Loan/Products',
                type: 'POST',
                data: { id: button.attr("data-id"), _csrf_token: $("#csrf").val() },
                success: function(result) {
                    console.log(result);
                    if (result.status === 0) {
                        Swal.fire(
                            'Success',
                            result.message,
                            'success'
                        ).then(() => {
                            location.reload(true);
                            spinner.hide();
                        });
                    } else {
                        Swal.fire(
                            'Error',
                            result.message,
                            'error'
                        )
                    }
                },
                error: function(request, msg, error) {
                    Swal.fire(
                        'Oops..',
                        error,
                        'error'
                    )
                },
            });
        } else {
            Swal.fire(
                'error',
                'Operation not performed :)',
                'error'
            )
        }
    });
});

//Approve Savings Product 
$('#dt-basic-example').on('click', '.js-sweetalert2-approve_savings_products', function(e) {
    e.preventDefault();
    var button = $(this);
    // prompt("Are you sure")
    Swal.fire({
        title: 'Are sure you?',
        text: "You want to approve!",
        type: "warning",
        showCancelButton: true,
        confirmButtonColor: '#23b05d',
        cancelButtonColor: '#d33',
        confirmButtonText: 'Yes!',
        showLoaderOnConfirm: true
    }).then((result) => {
        if (result.value) {
            $.ajax({
                url: '/Approve/Savings/Products',
                type: 'POST',
                data: { id: button.attr("data-id"), _csrf_token: $("#csrf").val() },
                success: function(result) {
                    console.log(result);
                    if (result.status === 0) {
                        Swal.fire(
                            'Success',
                            result.message,
                            'success'
                        ).then(() => {
                            location.reload(true);
                            spinner.hide();
                        });
                    } else {
                        Swal.fire(
                            'Error',
                            result.message,
                            'error'
                        )
                    }
                },
                error: function(request, msg, error) {
                    Swal.fire(
                        'Oops..',
                        error,
                        'error'
                    )
                },
            });
        } else {
            Swal.fire(
                'error',
                'Operation not performed :)',
                'error'
            )
        }
    });
});

//Approve Individual
$('#dt-basic-example').on('click', '.js-sweetalert2-approve_individual', function(e) {
    e.preventDefault();
    var button = $(this);
    // prompt("Are you sure")
    Swal.fire({
        title: 'Are sure you?',
        text: "You want to approve!",
        type: "warning",
        showCancelButton: true,
        confirmButtonColor: '#23b05d',
        cancelButtonColor: '#d33',
        confirmButtonText: 'Yes!',
        showLoaderOnConfirm: true
    }).then((result) => {
        if (result.value) {
            $.ajax({
                url: '/Approve/Individual',
                type: 'POST',
                data: { id: button.attr("data-id"), _csrf_token: $("#csrf").val() },
                success: function(result) {
                    console.log(result);
                    if (result.status === 0) {
                        Swal.fire(
                            'Success',
                            result.message,
                            'success'
                        ).then(() => {
                            location.reload(true);
                            spinner.hide();
                        });
                    } else {
                        Swal.fire(
                            'Error',
                            result.message,
                            'error'
                        )
                    }
                },
                error: function(request, msg, error) {
                    Swal.fire(
                        'Oops..',
                        error,
                        'error'
                    )
                },
            });
        } else {
            Swal.fire(
                'error',
                'Operation not performed :)',
                'error'
            )
        }
    });
});

//Approve SME
$('#dt-basic-example').on('click', '.js-sweetalert2-approve_sme', function(e) {
    e.preventDefault();
    var button = $(this);
    // prompt("Are you sure")
    Swal.fire({
        title: 'Are sure you?',
        text: "You want to approve!",
        type: "warning",
        showCancelButton: true,
        confirmButtonColor: '#23b05d',
        cancelButtonColor: '#d33',
        confirmButtonText: 'Yes!',
        showLoaderOnConfirm: true
    }).then((result) => {
        if (result.value) {
            $.ajax({
                url: '/Approve/SME',
                type: 'POST',
                data: { id: button.attr("data-id"), _csrf_token: $("#csrf").val() },
                success: function(result) {
                    console.log(result);
                    if (result.status === 0) {
                        Swal.fire(
                            'Success',
                            result.message,
                            'success'
                        ).then(() => {
                            location.reload(true);
                            spinner.hide();
                        });
                    } else {
                        Swal.fire(
                            'Error',
                            result.message,
                            'error'
                        )
                    }
                },
                error: function(request, msg, error) {
                    Swal.fire(
                        'Oops..',
                        error,
                        'error'
                    )
                },
            });
        } else {
            Swal.fire(
                'error',
                'Operation not performed :)',
                'error'
            )
        }
    });
});